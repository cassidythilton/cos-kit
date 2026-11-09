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

// Sampled from the Grokbot marks: CHIEF blue, OPS pink, BUILDER amber, KEEPER grey, STEWARD orange.
export const BOT_COLOR: Record<string, string> = {
  CHIEF: "#3d80f1",
  OPS: "#e54796",
  STEWARD: "#e66f30",
  BUILDER: "#e79738",
  KEEPER: "#757675",
  EVAL: "#c0392b",
  SYSTEM: "#3d4452",
};
