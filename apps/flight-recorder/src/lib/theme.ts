// Chart colours. Keep in step with the custom properties in styles.css.
// Lane series stay grey. Green is only good news. Bot colours are not chart colours.
export const COLORS = {
  ground: "#ECECEA",
  ink: "#141416",
  muted: "#6B6B70",
  accent: "#141416",
  deep: "#141416",
  signal: "#5EE38F",
  resolved: "#D4D4D2",
  gap: "#1C1C1F",
} as const;

export const LANE_GREY = ["#141416", "#3a3a3e", "#6B6B70", "#8d8d92", "#b7b7b4", "#d4d4d2"];

export const BOT_COLOR: Record<string, string> = {
  CHIEF: "#2f55c8",
  OPS: "#0f8a7e",
  STEWARD: "#b26a00",
  BUILDER: "#8a3fb5",
  KEEPER: "#c0392b",
  EVAL: "#c0392b",
  SYSTEM: "#3d4452",
};
