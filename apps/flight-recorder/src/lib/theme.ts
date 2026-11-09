// Chart colours. Keep in step with the custom properties in styles.css.
// Lane series stay grey. Green is only good news. Bot colours are not chart colours.
export const COLORS = {
  bg: "#0a0a0a",
  panel: "#111112",
  ink: "#ededed",
  muted: "#8a8a90",
  signal: "#5ee38f",
} as const;

export const LANE_GREY = ["#8a8a90", "#5c5c62", "#c8c8cc", "#3e3e44", "#a3a3a8", "#6e6e74"];

export const BOT_COLOR: Record<string, string> = {
  CHIEF: "#2f55c8",
  OPS: "#0f8a7e",
  STEWARD: "#b26a00",
  BUILDER: "#8a3fb5",
  KEEPER: "#c0392b",
  EVAL: "#c0392b",
  SYSTEM: "#3d4452",
};
