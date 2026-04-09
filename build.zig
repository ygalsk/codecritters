const std = @import("std");

pub fn build(b: *std.Build) void {
    const target = b.standardTargetOptions(.{});
    const optimize = b.standardOptimizeOption(.{});

    const vaxis_dep = b.dependency("vaxis", .{
        .target = target,
        .optimize = optimize,
    });

    const zqlite_dep = b.dependency("zqlite", .{
        .target = target,
        .optimize = optimize,
    });

    // Shared data modules — named so battle/ can import them without ../
    // and type identity is preserved across all consumers.
    const types_mod = b.createModule(.{
        .root_source_file = b.path("src/data/types.zig"),
        .target = target,
        .optimize = optimize,
    });
    const loader_mod = b.createModule(.{
        .root_source_file = b.path("src/data/loader.zig"),
        .target = target,
        .optimize = optimize,
    });
    const moves_mod = b.createModule(.{
        .root_source_file = b.path("src/data/moves.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types.zig", .module = types_mod },
            .{ .name = "loader.zig", .module = loader_mod },
        },
    });
    const species_mod = b.createModule(.{
        .root_source_file = b.path("src/data/species.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types.zig", .module = types_mod },
            .{ .name = "loader.zig", .module = loader_mod },
        },
    });
    const items_mod = b.createModule(.{
        .root_source_file = b.path("src/data/items.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "types.zig", .module = types_mod },
            .{ .name = "loader.zig", .module = loader_mod },
        },
    });
    const critter_mod = b.createModule(.{
        .root_source_file = b.path("src/data/critter.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "species.zig", .module = species_mod },
        },
    });
    const game_data_mod = b.createModule(.{
        .root_source_file = b.path("src/data/game_data.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "species.zig", .module = species_mod },
            .{ .name = "moves.zig", .module = moves_mod },
            .{ .name = "items.zig", .module = items_mod },
        },
    });

    // Leveling module — needs critter, species, game_data
    const leveling_mod = b.createModule(.{
        .root_source_file = b.path("src/data/leveling.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "critter", .module = critter_mod },
            .{ .name = "species", .module = species_mod },
            .{ .name = "game_data", .module = game_data_mod },
        },
    });

    // Equip module — needs critter, items
    const equip_mod = b.createModule(.{
        .root_source_file = b.path("src/data/equip.zig"),
        .target = target,
        .optimize = optimize,
        .imports = &.{
            .{ .name = "critter", .module = critter_mod },
            .{ .name = "items", .module = items_mod },
        },
    });

    // Battle engine modules — import data types via named modules
    const battle_data_imports: []const std.Build.Module.Import = &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "moves", .module = moves_mod },
        .{ .name = "species", .module = species_mod },
        .{ .name = "items", .module = items_mod },
        .{ .name = "critter", .module = critter_mod },
        .{ .name = "game_data", .module = game_data_mod },
    };

    // Battle engine as a named module (shares data type identity with everything else)
    const battle_mod = b.createModule(.{
        .root_source_file = b.path("src/battle/battle.zig"),
        .target = target,
        .optimize = optimize,
        .imports = battle_data_imports,
    });

    // Dungeon engine modules — import data types via named modules
    const dungeon_data_imports: []const std.Build.Module.Import = &.{
        .{ .name = "types", .module = types_mod },
        .{ .name = "species", .module = species_mod },
        .{ .name = "items", .module = items_mod },
        .{ .name = "critter", .module = critter_mod },
        .{ .name = "game_data", .module = game_data_mod },
        .{ .name = "loader", .module = loader_mod },
    };

    const dungeon_mod = b.createModule(.{
        .root_source_file = b.path("src/dungeon/dungeon.zig"),
        .target = target,
        .optimize = optimize,
        .imports = dungeon_data_imports,
    });

    const exe = b.addExecutable(.{
        .name = "codecritter",
        .root_module = b.createModule(.{
            .root_source_file = b.path("src/main.zig"),
            .target = target,
            .optimize = optimize,
            .imports = &.{
                .{ .name = "vaxis", .module = vaxis_dep.module("vaxis") },
                .{ .name = "zqlite", .module = zqlite_dep.module("zqlite") },
                .{ .name = "battle", .module = battle_mod },
                .{ .name = "game_data", .module = game_data_mod },
                .{ .name = "types", .module = types_mod },
                .{ .name = "species", .module = species_mod },
                .{ .name = "moves", .module = moves_mod },
                .{ .name = "items", .module = items_mod },
                .{ .name = "critter", .module = critter_mod },
                .{ .name = "dungeon", .module = dungeon_mod },
                .{ .name = "leveling", .module = leveling_mod },
                .{ .name = "equip", .module = equip_mod },
            },
        }),
    });
    // GCC 15's crt1.o has .sframe sections with R_X86_64_PC64 relocations that
    // Zig's bundled lld can't handle. --gc-sections discards unreferenced .sframe.
    exe.link_gc_sections = true;

    b.installArtifact(exe);

    const run_cmd = b.addRunArtifact(exe);
    run_cmd.step.dependOn(b.getInstallStep());
    if (b.args) |args| {
        run_cmd.addArgs(args);
    }

    const run_step = b.step("run", "Run Codecritter");
    run_step.dependOn(&run_cmd.step);

    // Test step — runs tests from all data and db modules
    const test_step = b.step("test", "Run unit tests");

    const data_test_modules = [_][]const u8{
        "src/data/types.zig",
        "src/data/moves.zig",
        "src/data/species.zig",
        "src/data/items.zig",
        "src/data/critter.zig",
        "src/data/game_data.zig",
    };
    for (data_test_modules) |test_file| {
        const unit_test = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(test_file),
                .target = target,
                .optimize = optimize,
            }),
        });
        const run_test = b.addRunArtifact(unit_test);
        test_step.dependOn(&run_test.step);
    }

    const db_test_modules = [_][]const u8{
        "src/db/db.zig",
        "src/db/roster.zig",
        "src/db/run_store.zig",
    };
    for (db_test_modules) |test_file| {
        const unit_test = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(test_file),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "zqlite", .module = zqlite_dep.module("zqlite") },
                    .{ .name = "critter", .module = critter_mod },
                },
            }),
        });
        unit_test.link_gc_sections = true;
        const run_test = b.addRunArtifact(unit_test);
        test_step.dependOn(&run_test.step);
    }

    // Leveling and equip tests
    {
        const leveling_test = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/data/leveling.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "critter", .module = critter_mod },
                    .{ .name = "species", .module = species_mod },
                    .{ .name = "game_data", .module = game_data_mod },
                },
            }),
        });
        const run_leveling_test = b.addRunArtifact(leveling_test);
        test_step.dependOn(&run_leveling_test.step);
    }
    {
        const equip_test = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/data/equip.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "critter", .module = critter_mod },
                    .{ .name = "items", .module = items_mod },
                },
            }),
        });
        const run_equip_test = b.addRunArtifact(equip_test);
        test_step.dependOn(&run_equip_test.step);
    }

    // Sprite tests (need vaxis for types)
    {
        const sprite_test = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/ui/sprite.zig"),
                .target = target,
                .optimize = optimize,
                .imports = &.{
                    .{ .name = "vaxis", .module = vaxis_dep.module("vaxis") },
                },
            }),
        });
        const run_sprite_test = b.addRunArtifact(sprite_test);
        test_step.dependOn(&run_sprite_test.step);
    }

    const battle_test_modules = [_][]const u8{
        "src/battle/damage.zig",
        "src/battle/status.zig",
        "src/battle/catch.zig",
        "src/battle/ai.zig",
        "src/battle/battle.zig",
    };
    for (battle_test_modules) |test_file| {
        const unit_test = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(test_file),
                .target = target,
                .optimize = optimize,
                .imports = battle_data_imports,
            }),
        });
        const run_test = b.addRunArtifact(unit_test);
        test_step.dependOn(&run_test.step);
    }

    // Dungeon engine tests
    // floor_gen.zig has no external deps — test standalone
    {
        const floor_gen_test = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path("src/dungeon/floor_gen.zig"),
                .target = target,
                .optimize = optimize,
            }),
        });
        const run_fg_test = b.addRunArtifact(floor_gen_test);
        test_step.dependOn(&run_fg_test.step);
    }

    const dungeon_test_modules = [_][]const u8{
        "src/dungeon/biome.zig",
        "src/dungeon/shop.zig",
        "src/dungeon/dungeon.zig",
    };
    for (dungeon_test_modules) |test_file| {
        const unit_test = b.addTest(.{
            .root_module = b.createModule(.{
                .root_source_file = b.path(test_file),
                .target = target,
                .optimize = optimize,
                .imports = dungeon_data_imports,
            }),
        });
        const run_test = b.addRunArtifact(unit_test);
        test_step.dependOn(&run_test.step);
    }
}
