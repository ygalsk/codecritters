const vaxis = @import("vaxis");
const colors_mod = @import("colors.zig");

pub const Style = vaxis.Cell.Style;
pub const Color = vaxis.Cell.Color;

// ── Named Colors ──

pub const white: Color = .{ .rgb = .{ 255, 255, 255 } };
pub const black: Color = .{ .rgb = .{ 0, 0, 0 } };
pub const gold: Color = .{ .rgb = .{ 255, 200, 40 } };
pub const cyan: Color = .{ .rgb = .{ 80, 200, 255 } };
pub const green: Color = .{ .rgb = .{ 80, 255, 120 } };
pub const purple: Color = .{ .rgb = .{ 180, 140, 255 } };
pub const error_red: Color = .{ .rgb = .{ 255, 60, 60 } };
pub const status_red: Color = .{ .rgb = .{ 255, 100, 100 } };
pub const scar_red: Color = .{ .rgb = .{ 255, 80, 80 } };
pub const cooldown_red: Color = .{ .rgb = .{ 200, 60, 60 } };
pub const cooldown_dim: Color = .{ .rgb = .{ 120, 60, 60 } };
pub const scar_label: Color = .{ .rgb = .{ 200, 100, 100 } };
pub const dim_gray: Color = .{ .rgb = .{ 100, 100, 100 } };
pub const light_gray: Color = .{ .rgb = .{ 200, 200, 200 } };
pub const text_gray: Color = .{ .rgb = .{ 220, 220, 220 } };
pub const header_gray: Color = .{ .rgb = .{ 180, 180, 180 } };
pub const muted: Color = .{ .rgb = .{ 140, 140, 160 } };
pub const info_gray: Color = .{ .rgb = .{ 120, 120, 140 } };
pub const move_info: Color = .{ .rgb = .{ 150, 150, 150 } };
pub const press_key: Color = .{ .rgb = .{ 150, 150, 150 } };
pub const party_green: Color = .{ .rgb = .{ 150, 255, 150 } };
pub const currency_gold: Color = .{ .rgb = .{ 180, 180, 100 } };
pub const category_gold: Color = .{ .rgb = .{ 255, 200, 80 } };
pub const outcome_yellow: Color = .{ .rgb = .{ 255, 255, 100 } };
pub const separator: Color = .{ .rgb = .{ 80, 80, 80 } };
pub const bar_empty: Color = .{ .rgb = .{ 60, 60, 60 } };

// ── Semantic Style Presets ──

pub const title: Style = .{ .fg = cyan, .bold = true };
pub const heading: Style = .{ .fg = white, .bold = true };
pub const body: Style = .{ .fg = light_gray };
pub const body_bright: Style = .{ .fg = text_gray };
pub const header: Style = .{ .fg = header_gray };
pub const dim: Style = .{ .fg = dim_gray };
pub const hint: Style = .{ .fg = dim_gray };
pub const selected: Style = .{ .fg = black, .bg = white, .bold = true };
pub const selected_text: Style = .{ .fg = white, .bold = true };
pub const unselected: Style = .{ .fg = light_gray };
pub const currency: Style = .{ .fg = currency_gold };
pub const currency_bold: Style = .{ .fg = gold, .bold = true };
pub const category: Style = .{ .fg = category_gold, .bold = true };
pub const err: Style = .{ .fg = error_red };
pub const xp: Style = .{ .fg = gold, .bold = true };
pub const level_up: Style = .{ .fg = green, .bold = true };
pub const item_found: Style = .{ .fg = purple };

// ── Re-exported color functions ──

pub const typeColor = colors_mod.typeColor;
pub const hpColor = colors_mod.hpColor;
pub const rarityColor = colors_mod.rarityColor;
