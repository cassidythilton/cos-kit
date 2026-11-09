import { useEffect, useMemo, useState } from "react";
import { QuestionSelect, type Option } from "./components/QuestionSelect";
import { SourceRef } from "./components/SourceRef";
import { BOT_COLOR, LANE_GREY } from "./lib/theme";

type Source = { tables: string[]; sql: string };
type Envelope<T> = { source: Source; data_through: string | null; data: T; empty?: boolean };

interface Summary {
  jobs: number;
  claude_spend: number;
  checker_pass: number;
  checker_fail: number;
  checker_rate: number | null;
  verifier_levels: Record<string, number>;
  gate_blocks: number;
  gate_asks: number;
  missed_or_failed: number;
  open_corrections: number;
  cursor_runs: number;
  codex_runs: number;
  partial: boolean;
  start_day: string;
  end_day: string;
}

interface JobRow {
  job: string;
  lane: string;
  bot: string;
  started: string | null;
  secs: number | null;
  status: string | null;
  checker: string | null;
  verifier_level: string | null;
  cost_usd: number | null;
  engine: string | null;
}

interface SpendDay {
  day: string;
  partial: boolean;
  dollars: Record<string, number>;
  runs: Record<string, number>;
  codex: number;
}

interface GateEvent {
  id: string;
  ts: string;
  decision: string;
  rule: string;
  tool: string;
  job: string;
  cmd: string;
  path: string;
}

interface Detail {
  job: JobRow & { summary?: string; folder?: string; needs_approval_json?: string; checker_failures?: string; verifier_json?: string; baseline_reading?: string };
  brief: string;
  files: { path: string; op: string }[];
  commands: { seq: number; command: string; tool: string }[];
  gate: GateEvent[];
  pushes: { ts: string; bot: string; slot: string; code: string }[];
  applies: { ts: string; sha: string; writes: number | null; ok: number | null; status: string }[];
}

const WINDOWS: Option[] = [
  { id: "1d", kicker: "Window", label: "Today", proof: "The newest day in the recorder." },
  { id: "7d", kicker: "Window", label: "7 days", proof: "Seven days ending on the newest day." },
  { id: "30d", kicker: "Window", label: "30 days", proof: "Thirty days ending on the newest day." },
];

const BOTS: Option[] = ["", "CHIEF", "OPS", "STEWARD", "BUILDER", "KEEPER", "EVAL", "SYSTEM"].map((id) => ({
  id: id || "all",
  kicker: "Bot",
  label: id || "Every bot",
  proof: id ? `Jobs attributed to ${id}.` : "No bot filter.",
}));

const LANES: Option[] = ["", "quick", "investigate", "draft", "build", "apply", "eval", "note", "pause"].map((id) => ({
  id: id || "all",
  kicker: "Lane",
  label: id || "Every lane",
  proof: id ? `The ${id} lane.` : "No lane filter.",
}));

const STATUSES: Option[] = ["", "done", "blocked", "failed", "partial", "running"].map((id) => ({
  id: id || "all",
  kicker: "Status",
  label: id || "Every status",
  proof: id ? `Jobs marked ${id}.` : "No status filter.",
}));

async function get<T>(path: string): Promise<Envelope<T>> {
  const response = await fetch(path);
  if (!response.ok) throw new Error(`${response.status} ${path}`);
  return response.json();
}

function money(value: number | null | undefined): string {
  if (value == null) return "—";
  return `$${value.toFixed(2)}`;
}

function duration(secs: number | null): string {
  if (secs == null) return "—";
  if (secs < 60) return `${secs}s`;
  return `${Math.floor(secs / 60)}m ${secs % 60}s`;
}

function clock(stamp: string | null): string {
  if (!stamp) return "—";
  const parsed = new Date(stamp);
  if (Number.isNaN(parsed.getTime())) return stamp.slice(11, 16);
  return parsed.toLocaleString(undefined, { month: "short", day: "numeric", hour: "2-digit", minute: "2-digit" });
}

function fresh(stamp: string | null): boolean {
  if (!stamp) return false;
  return Date.now() - new Date(stamp).getTime() < 15 * 60 * 1000;
}

function parseJson<T>(text: string | undefined, fallback: T): T {
  if (!text) return fallback;
  try { return JSON.parse(text) as T; } catch { return fallback; }
}

export default function App() {
  const [windowId, setWindowId] = useState("1d");
  const [summary, setSummary] = useState<Envelope<Summary> | null>(null);
  const [spend, setSpend] = useState<Envelope<{ days: SpendDay[] }> | null>(null);
  const [jobs, setJobs] = useState<Envelope<JobRow[]> | null>(null);
  const [gates, setGates] = useState<Envelope<GateEvent[]> | null>(null);
  const [approvals, setApprovals] = useState<Envelope<{ ts: string; job: string; sha: string; writes: number | null; ok: number | null; status: string; kind: string }[]> | null>(null);
  const [schedule, setSchedule] = useState<Envelope<{ slots: string[]; days: string[]; cells: Record<string, { outcome: string; time: string; msg: string }> }> | null>(null);
  const [corrections, setCorrections] = useState<Envelope<{ ts: string; bot: string; note: string }[]> | null>(null);
  const [evals, setEvals] = useState<Envelope<{ run: string; ts: string; arms: string; checker_pass: string; cost: string }[]> | null>(null);
  const [board, setBoard] = useState<Envelope<Record<string, string>[]> | null>(null);
  const [bot, setBot] = useState("all");
  const [lane, setLane] = useState("all");
  const [status, setStatus] = useState("all");
  const [query, setQuery] = useState("");
  const [error, setError] = useState("");
  const [openJob, setOpenJob] = useState<string | null>(null);

  useEffect(() => {
    let cancel = false;
    const params = new URLSearchParams({
      window: windowId,
      bot: bot === "all" ? "" : bot,
      lane: lane === "all" ? "" : lane,
      status: status === "all" ? "" : status,
      q: query,
    });
    Promise.all([
      get<Summary>(`/api/summary?window=${windowId}`),
      get<{ days: SpendDay[] }>(`/api/spend?days=${windowId === "30d" ? 30 : windowId === "7d" ? 7 : 1}`),
      get<JobRow[]>(`/api/jobs?${params}`),
      get<GateEvent[]>(`/api/gate?window=${windowId}`),
      get<{ ts: string; job: string; sha: string; writes: number | null; ok: number | null; status: string; kind: string }[]>("/api/approvals"),
      get<{ slots: string[]; days: string[]; cells: Record<string, { outcome: string; time: string; msg: string }> }>("/api/schedule?days=14"),
      get<{ ts: string; bot: string; note: string }[]>(`/api/corrections?window=${windowId}`),
      get<{ run: string; ts: string; arms: string; checker_pass: string; cost: string }[]>("/api/evals"),
      get<Record<string, string>[]>("/api/board-health"),
    ]).then(([a, b, c, d, e, f, g, h, i]) => {
      if (cancel) return;
      setSummary(a); setSpend(b); setJobs(c); setGates(d); setApprovals(e);
      setSchedule(f); setCorrections(g); setEvals(h); setBoard(i); setError("");
    }).catch((err: Error) => { if (!cancel) setError(err.message); });
    return () => { cancel = true; };
  }, [windowId, bot, lane, status, query]);

  const through = summary?.data_through ?? null;

  return (
    <main className="page">
      <header className="masthead">
        <div>
          <p className="eyebrow">This Mac</p>
          <h1 className="headline">What ran, what it <em>cost</em>, what got blocked.</h1>
        </div>
        <div className="masthead-tools">
          <QuestionSelect options={WINDOWS} value={windowId} onChange={setWindowId} label="Window" />
          <Freshness stamp={through} />
        </div>
      </header>
      {error && <p className="empty"><strong>The page could not load.</strong> {error}</p>}
      <Tiles summary={summary} />
      <Spend spend={spend} />
      <Jobs
        jobs={jobs}
        bot={bot} lane={lane} status={status} query={query}
        onBot={setBot} onLane={setLane} onStatus={setStatus} onQuery={setQuery}
        onOpen={setOpenJob}
      />
      <Walls gates={gates} />
      <Approvals approvals={approvals} />
      <ScheduleGrid schedule={schedule} />
      <Learning corrections={corrections} evals={evals} board={board} />
      <footer className="colophon">
        <p><strong>What this cannot see.</strong> Grok’s own app calls (Gmail, Slack, calendar, its browser) and Grok usage live in the Grok app’s Activity and Settings → Usage & Billing. Cursor and Codex report no dollars, so they are counted as runs.</p>
      </footer>
      {openJob && <Drawer job={openJob} onClose={() => setOpenJob(null)} />}
    </main>
  );
}

function Freshness({ stamp }: { stamp: string | null }) {
  const stale = !fresh(stamp);
  const label = stamp ? `Data through ${clock(stamp)}` : "No ledger line yet";
  return (
    <p className={stale ? "freshness is-stale" : "freshness"}>
      <span className="freshness-dot" aria-hidden="true" />
      {label}{stale ? " · older than 15 minutes" : ""}
    </p>
  );
}

function Tiles({ summary }: { summary: Envelope<Summary> | null }) {
  const data = summary?.data;
  if (!data) return <p className="empty"><strong>Nothing loaded yet.</strong> cos-db load fills this from the ledger and the outbox.</p>;
  const rate = data.checker_rate == null ? "—" : `${Math.round(data.checker_rate * 100)}%`;
  const checked = data.checker_pass + data.checker_fail;
  return (
    <section aria-label="Summary">
      <div className="tiles">
        <Tile label="Jobs" value={String(data.jobs)} detail={data.partial ? "Newest day is partial." : "Full days."} tone="neutral" />
        <Tile label="Claude spend" value={money(data.claude_spend)} detail={`${data.cursor_runs} Cursor runs, ${data.codex_runs} Codex reviews, no dollars.`} tone="neutral" />
        <Tile label="Checker pass" value={rate} detail={checked ? `${data.checker_pass} of ${checked}` : "No checker on these runs."} tone={checked === 0 ? "neutral" : data.checker_rate === 1 ? "good" : "amber"} />
        <Tile label="Gate blocks" value={String(data.gate_blocks)} detail={`${data.gate_asks} asks`} tone={data.gate_blocks > 0 ? "coral" : "good"} />
        <Tile label="Missed or failed" value={String(data.missed_or_failed)} detail="Scheduled runs." tone={data.missed_or_failed > 0 ? "coral" : "good"} />
        <Tile label="Open corrections" value={String(data.open_corrections)} detail="No closed flag. Every note is open." tone={data.open_corrections > 0 ? "amber" : "good"} />
      </div>
      {summary && <SourceRef table={summary.source.tables.join(", ")} reads={summary.source.sql} />}
    </section>
  );
}

function Tile({ label, value, detail, tone }: { label: string; value: string; detail: string; tone: "neutral" | "good" | "amber" | "coral" }) {
  return (
    <article className={`tile${tone === "neutral" ? "" : ` is-${tone}`}`}>
      <p className="tile-label">{label}</p>
      <p className="tile-value">{value}</p>
      <p className="tile-detail">{detail}</p>
    </article>
  );
}

function Spend({ spend }: { spend: Envelope<{ days: SpendDay[] }> | null }) {
  const days = spend?.data?.days ?? [];
  const lanes = useMemo(() => {
    const names = new Set<string>();
    days.forEach((day) => Object.keys(day.dollars).forEach((lane) => names.add(lane)));
    return [...names];
  }, [days]);
  const maxDollars = Math.max(0.01, ...days.map((day) => Object.values(day.dollars).reduce((sum, n) => sum + n, 0)));
  const maxRuns = Math.max(1, ...days.map((day) => Object.values(day.runs).reduce((sum, n) => sum + n, 0)));
  const slot = 640 / Math.max(1, days.length);
  const width = Math.min(48, Math.max(10, slot - 12));
  const points = days.map((day, index) => {
    const x = 40 + index * slot + (slot - width) / 2;
    const runs = Object.values(day.runs).reduce((sum, n) => sum + n, 0);
    return { day, x, runs, ly: 180 - (runs / maxRuns) * 150 };
  });
  const line = points.map((point) => `${point.x + width / 2},${point.ly}`).join(" ");
  return (
    <section className="card" aria-labelledby="spend-title">
      <div className="card-head">
        <div>
          <h2 id="spend-title" className="card-title">Spend by day</h2>
          <p className="card-sub">Bars are Claude dollars by lane. The line is run counts. Cursor and Codex are counts, labeled in the table.</p>
        </div>
      </div>
      {days.length === 0 ? <p className="empty"><strong>No runs in this range yet.</strong> A job receipt lands here after cos-db load.</p> : (
        <div className="chart-host">
          <svg viewBox="0 0 720 220" role="img" aria-label="Claude dollars by day and run counts">
            {points.length > 1 && <polyline points={line} fill="none" stroke="#141416" strokeWidth="1.5" />}
            {points.map((point) => {
              const day = point.day;
              let y = 180;
              const total = Object.values(day.dollars).reduce((sum, n) => sum + n, 0);
              const bars = lanes.map((lane) => {
                const value = day.dollars[lane] || 0;
                const h = (value / maxDollars) * 150;
                y -= h;
                return { lane, y, h, value };
              });
              return (
                <g key={day.day}>
                  {bars.map((bar, i) => bar.h > 0 && (
                    <rect key={bar.lane} x={point.x} y={bar.y} width={width} height={bar.h} fill={LANE_GREY[i % LANE_GREY.length]}>
                      <title>{`${day.day} ${bar.lane} $${bar.value.toFixed(2)}`}</title>
                    </rect>
                  ))}
                  {total === 0 && <rect x={point.x} y={176} width={width} height={4} fill="#d4d4d2" />}
                  <circle cx={point.x + width / 2} cy={point.ly} r="3.5" fill="#141416">
                    <title>{`${day.day} ${point.runs} runs`}</title>
                  </circle>
                  <text x={point.x + width / 2} y="198" textAnchor="middle" fontSize="11" fill="#6b6b70">{day.day.slice(5)}{day.partial ? "*" : ""}</text>
                </g>
              );
            })}
            <line x1="40" y1="180" x2="700" y2="180" stroke="#dededc" />
          </svg>
          <ul className="legend">
            {lanes.map((lane, i) => (
              <li key={lane}><span className="swatch" style={{ background: LANE_GREY[i % LANE_GREY.length] }} />{lane}</li>
            ))}
            <li><span className="swatch" style={{ background: "#141416", borderRadius: "50%" }} />run count</li>
          </ul>
        </div>
      )}
      {days.length > 0 && (
        <div className="table-wrap">
          <table className="data-table">
            <thead>
              <tr>
                <th>Day</th>
                {lanes.map((lane) => <th key={lane} className="num">{lane}</th>)}
                <th className="num">Runs</th>
                <th className="num">Codex</th>
              </tr>
            </thead>
            <tbody>
              {days.map((day) => (
                <tr key={day.day}>
                  <td>{day.day}{day.partial ? " · partial" : ""}</td>
                  {lanes.map((lane) => <td key={lane} className="num">{money(day.dollars[lane] || 0)}</td>)}
                  <td className="num">{Object.entries(day.runs).map(([engine, n]) => `${engine} ${n}`).join(", ") || "0"}</td>
                  <td className="num">{day.codex}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {spend && <SourceRef table={spend.source.tables.join(", ")} reads={spend.source.sql} />}
    </section>
  );
}

function Jobs({ jobs, bot, lane, status, query, onBot, onLane, onStatus, onQuery, onOpen }: {
  jobs: Envelope<JobRow[]> | null;
  bot: string; lane: string; status: string; query: string;
  onBot: (id: string) => void; onLane: (id: string) => void; onStatus: (id: string) => void; onQuery: (q: string) => void;
  onOpen: (job: string) => void;
}) {
  const list = jobs?.data ?? [];
  return (
    <section className="card" aria-labelledby="jobs-title">
      <div className="card-head">
        <div>
          <h2 id="jobs-title" className="card-title">Jobs</h2>
          <p className="card-sub">Newest first. A row opens the receipt, the files and the commands.</p>
        </div>
      </div>
      <div className="filters">
        <QuestionSelect options={BOTS} value={bot} onChange={onBot} label="Bot" />
        <QuestionSelect options={LANES} value={lane} onChange={onLane} label="Lane" />
        <QuestionSelect options={STATUSES} value={status} onChange={onStatus} label="Status" />
        <input className="search" value={query} placeholder="Search job or summary" aria-label="Search jobs" onChange={(event) => onQuery(event.target.value)} />
      </div>
      {list.length === 0 ? <p className="empty"><strong>No jobs in this window.</strong> A fresh install fills this after the first cos-run.</p> : (
        <div className="table-wrap">
          <table className="data-table">
            <thead>
              <tr>
                <th>Time</th><th>Job</th><th>Bot</th><th>Lane</th><th>Status</th><th>Checker</th><th>Verifier</th><th className="num">Cost</th><th className="num">Duration</th>
              </tr>
            </thead>
            <tbody>
              {list.map((row) => (
                <tr key={row.job} className="is-clickable" onClick={() => onOpen(row.job)}>
                  <td>{clock(row.started)}</td>
                  <td><button type="button" className="link-button" onClick={() => onOpen(row.job)}>{row.job}</button></td>
                  <td><BotPill bot={row.bot} /></td>
                  <td>{row.lane || "—"}</td>
                  <td><StatusPill status={row.status} /></td>
                  <td>{row.checker || "—"}</td>
                  <td>{row.verifier_level || "—"}</td>
                  <td className="num">{row.engine === "cursor-agent" ? "count" : money(row.cost_usd)}</td>
                  <td className="num">{duration(row.secs)}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {jobs && <SourceRef table={jobs.source.tables.join(", ")} reads={jobs.source.sql} />}
    </section>
  );
}

function BotPill({ bot }: { bot: string }) {
  return (
    <span className="pill">
      <span className="pill-dot" style={{ background: BOT_COLOR[bot] || "#3d4452" }} aria-hidden="true" />
      {bot || "—"}
    </span>
  );
}

function StatusPill({ status }: { status: string | null }) {
  const tone = status === "failed" || status === "blocked" ? "is-coral" : status === "partial" || status === "running" ? "is-amber" : status === "done" ? "is-good" : "";
  return <span className={`pill ${tone}`}>{status || "—"}</span>;
}

function Walls({ gates }: { gates: Envelope<GateEvent[]> | null }) {
  const events = gates?.data ?? [];
  const byDay = new Map<string, { block: number; ask: number }>();
  const rules = new Map<string, number>();
  events.forEach((event) => {
    const day = event.ts.slice(0, 10);
    const bucket = byDay.get(day) || { block: 0, ask: 0 };
    if (event.decision === "ask") bucket.ask += 1; else bucket.block += 1;
    byDay.set(day, bucket);
    rules.set(event.rule || "(none)", (rules.get(event.rule || "(none)") || 0) + 1);
  });
  const days = [...byDay.entries()];
  const top = [...rules.entries()].sort((a, b) => b[1] - a[1]).slice(0, 8);
  const max = Math.max(1, ...days.map(([, v]) => v.block + v.ask));
  return (
    <section className="card" aria-labelledby="walls-title">
      <div className="card-head">
        <div>
          <h2 id="walls-title" className="card-title">The walls</h2>
          <p className="card-sub">Blocks and asks. Allows are not recorded.</p>
        </div>
      </div>
      {events.length === 0 ? <p className="empty"><strong>No blocks or asks in this window.</strong> The gate writes a line only when it blocks or asks. Older runs predate the ledger.</p> : (
        <div className="chart-host">
          <svg viewBox="0 0 720 180" role="img" aria-label="Gate blocks and asks by day">
            {days.map(([day, value], index) => {
              const slot = 640 / Math.max(1, days.length);
              const width = Math.min(48, Math.max(10, slot - 12));
              const x = 40 + index * slot + (slot - width) / 2;
              const bh = (value.block / max) * 110;
              const ah = (value.ask / max) * 110;
              return (
                <g key={day}>
                  <rect x={x} y={140 - bh - ah} width={width} height={ah} fill="#d4d4d2"><title>{`${day} ${value.ask} asks`}</title></rect>
                  <rect x={x} y={140 - bh} width={width} height={bh} fill="#141416"><title>{`${day} ${value.block} blocks`}</title></rect>
                  <text x={x + width / 2} y="162" textAnchor="middle" fontSize="11" fill="#6b6b70">{day.slice(5)}</text>
                </g>
              );
            })}
            <line x1="40" y1="140" x2="700" y2="140" stroke="#dededc" />
          </svg>
          <ul className="legend">
            <li><span className="swatch" style={{ background: "#141416" }} />block</li>
            <li><span className="swatch" style={{ background: "#d4d4d2" }} />ask</li>
          </ul>
        </div>
      )}
      {top.length > 0 && (
        <div className="table-wrap">
          <table className="data-table">
            <thead><tr><th>Rule</th><th className="num">Times</th></tr></thead>
            <tbody>{top.map(([rule, n]) => <tr key={rule}><td>{rule}</td><td className="num">{n}</td></tr>)}</tbody>
          </table>
        </div>
      )}
      {events.length > 0 && (
        <div className="table-wrap">
          <table className="data-table">
            <thead><tr><th>Time</th><th>Decision</th><th>Rule</th><th>Job</th><th>Command</th></tr></thead>
            <tbody>
              {events.map((event) => (
                <tr key={event.id}><td>{clock(event.ts)}</td><td>{event.decision}</td><td>{event.rule}</td><td>{event.job || "—"}</td><td>{event.cmd}</td></tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {gates && <SourceRef table="gate_events" reads={gates.source.sql} />}
    </section>
  );
}

function Approvals({ approvals }: { approvals: Envelope<{ ts: string; job: string; sha: string; writes: number | null; ok: number | null; status: string; kind: string }[]> | null }) {
  const list = approvals?.data ?? [];
  return (
    <section className="card" aria-labelledby="approvals-title">
      <h2 id="approvals-title" className="card-title">Approvals</h2>
      <p className="card-sub">Every apply batch: the sha256, the line count, the result, and the job it came from.</p>
      {list.length === 0 ? <p className="empty"><strong>No batch has been staged or applied.</strong> A job that writes apply.sh shows up here after the next load.</p> : (
        <div className="table-wrap">
          <table className="data-table">
            <thead><tr><th>When</th><th>Job</th><th>sha256</th><th className="num">Lines</th><th>Result</th></tr></thead>
            <tbody>
              {list.map((row) => (
                <tr key={`${row.job}-${row.sha}`}>
                  <td>{clock(row.ts)}</td>
                  <td>{row.job}</td>
                  <td><code>{(row.sha || "").slice(0, 12)}</code></td>
                  <td className="num">{row.writes ?? "—"}</td>
                  <td>{row.kind === "staged" ? "staged, not run" : `${row.ok ?? "—"} ok · ${row.status}`}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      {approvals && <SourceRef table={approvals.source.tables.join(", ")} reads={approvals.source.sql} />}
    </section>
  );
}

function ScheduleGrid({ schedule }: { schedule: Envelope<{ slots: string[]; days: string[]; cells: Record<string, { outcome: string; time: string; msg: string }> }> | null }) {
  const data = schedule?.data;
  if (!data) return null;
  const template = `120px repeat(${data.days.length}, minmax(64px, 1fr))`;
  return (
    <section className="card" aria-labelledby="schedule-title">
      <h2 id="schedule-title" className="card-title">Schedule health</h2>
      <p className="card-sub">One cell per slot and day. Hover for the time.</p>
      {data.days.length === 0 ? <p className="empty"><strong>No schedule rows yet.</strong> cos-sched writes these when a slot starts, skips, pauses or pushes.</p> : (
        <div className="grid">
          <div className="grid-row" style={{ gridTemplateColumns: template }}>
            <span />
            {data.days.map((day) => <span key={day} className="grid-head">{day.slice(5)}</span>)}
          </div>
          {data.slots.map((slot) => (
            <div key={slot} className="grid-row" style={{ gridTemplateColumns: template }}>
              <span className="grid-label">{slot}</span>
              {data.days.map((day) => {
                const cell = data.cells[`${slot}|${day}`];
                const outcome = cell?.outcome || "empty";
                const word = outcome === "pushed" ? "pushed" : outcome === "no change" ? "quiet" : outcome === "start" ? "ran" : outcome === "empty" ? "" : outcome;
                return <span key={day} className={`cell is-${outcome}`} title={cell ? `${cell.time} ${cell.msg}` : "nothing recorded"}>{word}</span>;
              })}
            </div>
          ))}
        </div>
      )}
      {schedule && <SourceRef table="schedule" reads={schedule.source.sql} />}
    </section>
  );
}

function Learning({ corrections, evals, board }: {
  corrections: Envelope<{ ts: string; bot: string; note: string }[]> | null;
  evals: Envelope<{ run: string; ts: string; arms: string; checker_pass: string; cost: string }[]> | null;
  board: Envelope<Record<string, string>[]> | null;
}) {
  const notes = corrections?.data ?? [];
  const byBot = new Map<string, number>();
  notes.forEach((note) => byBot.set(note.bot, (byBot.get(note.bot) || 0) + 1));
  const latest = evals?.data?.[0];
  const arms = parseJson<{ arm: string; mean_score: number; violations: number }[]>(latest?.arms, []);
  const health = board?.data ?? [];
  return (
    <section className="card" aria-labelledby="learn-title">
      <h2 id="learn-title" className="card-title">Learning</h2>
      <p className="card-sub">Open corrections, the latest eval, and the board-health trend.</p>
      <div className="tiles" style={{ marginTop: 12 }}>
        {[...byBot.entries()].map(([bot, n]) => (
          <article key={bot} className="tile">
            <p className="tile-label">{bot}</p>
            <p className="tile-value">{n}</p>
            <p className="tile-detail">open notes</p>
          </article>
        ))}
        {byBot.size === 0 && <p className="empty"><strong>No corrections in this window.</strong> cos-run note appends one.</p>}
      </div>
      {latest ? (
        <div className="table-wrap">
          <table className="data-table">
            <thead><tr><th>Arm</th><th className="num">Mean</th><th className="num">Violations</th><th>Checker</th></tr></thead>
            <tbody>
              {arms.map((arm) => (
                <tr key={arm.arm}>
                  <td>{arm.arm}</td>
                  <td className="num">{arm.mean_score}</td>
                  <td className="num">{arm.violations}</td>
                  <td>{parseJson<Record<string, string>>(latest.checker_pass, {})[arm.arm] || "—"}</td>
                </tr>
              ))}
            </tbody>
          </table>
        </div>
      ) : <p className="empty"><strong>No eval report yet.</strong> cos-run eval writes one under ~/cos/evals/runs.</p>}
      {health.length > 0 && (
        <div className="table-wrap">
          <table className="data-table">
            <thead>
              <tr>{Object.keys(health[0]).map((key) => <th key={key}>{key}</th>)}</tr>
            </thead>
            <tbody>
              {health.map((row) => (
                <tr key={row.as_of}>{Object.keys(health[0]).map((key) => <td key={key}>{row[key]}</td>)}</tr>
              ))}
            </tbody>
          </table>
        </div>
      )}
      <SourceRef
        table={[corrections?.source.tables.join(", "), evals?.source.tables.join(", "), board?.source.tables.join(", ")].filter(Boolean).join(", ") || "corrections, evals, board_health"}
        reads={[corrections?.source.sql, evals?.source.sql, board?.source.sql].filter(Boolean).join(" · ") || "notes in the window; latest report.json; every board-health row"}
      />
    </section>
  );
}

function Drawer({ job, onClose }: { job: string; onClose: () => void }) {
  const [detail, setDetail] = useState<Envelope<Detail> | null>(null);
  const [copied, setCopied] = useState(false);
  useEffect(() => {
    let cancel = false;
    get<Detail>(`/api/jobs/${encodeURIComponent(job)}`).then((next) => {
      if (!cancel) setDetail(next);
    }).catch(() => { if (!cancel) setDetail(null); });
    function onKey(event: KeyboardEvent) { if (event.key === "Escape") onClose(); }
    document.addEventListener("keydown", onKey);
    return () => {
      cancel = true;
      document.removeEventListener("keydown", onKey);
    };
    // onClose closes the drawer. Its identity changes every parent render; the job id is the fetch key.
    // eslint-disable-next-line react-hooks/exhaustive-deps
  }, [job]);
  const data = detail?.data;
  const failures = parseJson<string[]>(data?.job.checker_failures, []);
  const needs = parseJson<{ action: string; target: string; why: string }[]>(data?.job.needs_approval_json, []);
  const verifier = parseJson<{ criteria?: { criterion: string; status: string; evidence: string }[] }>(data?.job.verifier_json, {});
  const grouped = new Map<string, { op: string; path: string }[]>();
  (data?.files ?? []).forEach((file) => {
    const folder = file.path.split("/").slice(0, -1).join("/") || "/";
    const list = grouped.get(folder) || [];
    list.push(file);
    grouped.set(folder, list);
  });
  return (
    <>
      <button type="button" className="drawer-scrim" aria-label="Close job" onClick={onClose} />
      <aside className="drawer" role="dialog" aria-label={job}>
        <p className="eyebrow">Job</p>
        <h2 className="headline" style={{ fontSize: 28 }}>{job}</h2>
        {!data && <p className="empty">Loading…</p>}
        {data && (
          <>
            <section>
              <h3>Brief</h3>
              <pre>{data.brief || "No brief.md in the job folder."}</pre>
            </section>
            <section>
              <h3>Receipt</h3>
              <p>{data.job.summary || "No summary."}</p>
              {data.job.baseline_reading && <p className="card-sub">Baseline: {data.job.baseline_reading}</p>}
            </section>
            <section>
              <h3>Checker</h3>
              {failures.length === 0 ? <p className="empty">No checker failures stored.</p> : <ul>{failures.map((item) => <li key={item}>{item}</li>)}</ul>}
            </section>
            <section>
              <h3>Verifier</h3>
              {(verifier.criteria ?? []).length === 0 ? <p className="empty">No verifier criteria.</p> : (
                <ul>{(verifier.criteria ?? []).map((item) => <li key={item.criterion}><strong>{item.status}</strong> {item.criterion}</li>)}</ul>
              )}
            </section>
            <section>
              <h3>Needs approval</h3>
              {needs.length === 0 ? <p className="empty">Nothing staged.</p> : needs.map((item) => <p key={item.action}>{item.action} · {item.target}</p>)}
            </section>
            <section>
              <h3>Files</h3>
              {[...grouped.entries()].map(([folder, files]) => (
                <details key={folder} className="group" open>
                  <summary>{folder} · {files.length}</summary>
                  <ul>{files.map((file) => <li key={file.op + file.path}>{file.op} {file.path.split("/").pop()}</li>)}</ul>
                </details>
              ))}
              {grouped.size === 0 && <p className="empty">No transcript files for this job. Quick runs record commands from context.txt instead.</p>}
            </section>
            <section>
              <h3>Commands</h3>
              {data.commands.length === 0 ? <p className="empty">No commands recorded.</p> : (
                <ol>{data.commands.map((command) => <li key={command.seq}><code>{command.command}</code></li>)}</ol>
              )}
            </section>
            <section>
              <h3>Gate</h3>
              {data.gate.length === 0 ? <p className="empty">No gate event tied to this job.</p> : data.gate.map((event) => <p key={event.id}>{event.decision} · {event.rule} · {event.cmd}</p>)}
            </section>
            <section>
              <h3>Pushes</h3>
              {data.pushes.length === 0 ? <p className="empty">No push recorded.</p> : data.pushes.map((push) => <p key={push.ts}>{push.slot} → {push.bot} · {push.code}</p>)}
            </section>
            <section>
              <h3>Applies</h3>
              {data.applies.length === 0 ? <p className="empty">Not applied.</p> : data.applies.map((apply) => <p key={apply.sha}>{apply.status} · {apply.ok}/{apply.writes}</p>)}
            </section>
            <div className="folder-row">
              <code>{data.job.folder || "no folder"}</code>
              <button type="button" className="link-button" onClick={() => {
                if (data.job.folder) void navigator.clipboard.writeText(data.job.folder).then(() => setCopied(true));
              }}>{copied ? "Copied" : "Copy path"}</button>
            </div>
            {detail && <SourceRef table={detail.source.tables.join(", ")} reads={detail.source.sql} />}
          </>
        )}
      </aside>
    </>
  );
}
