import { useEffect, useId, useRef, useState } from "react";

export interface Option {
  id: string;
  kicker: string;
  label: string;
  proof: string;
}

export function QuestionSelect({
  options,
  value,
  onChange,
  label,
}: {
  options: Option[];
  value: string;
  onChange: (id: string) => void;
  label: string;
}) {
  const [open, setOpen] = useState(false);
  const [active, setActive] = useState(value);
  const rootRef = useRef<HTMLDivElement>(null);
  const listId = useId();
  const selected = options.find((item) => item.id === value) ?? options[0];

  useEffect(() => {
    if (open) setActive(value);
  }, [open, value]);

  useEffect(() => {
    function onDoc(event: MouseEvent) {
      if (!rootRef.current?.contains(event.target as Node)) setOpen(false);
    }
    document.addEventListener("mousedown", onDoc);
    return () => document.removeEventListener("mousedown", onDoc);
  }, []);

  function move(delta: number) {
    const index = options.findIndex((item) => item.id === active);
    const next = options[(index + delta + options.length) % options.length];
    setActive(next.id);
  }

  function choose(id: string) {
    onChange(id);
    setOpen(false);
  }

  return (
    <div className={open ? "q-select is-open" : "q-select"} ref={rootRef}>
      <button
        type="button"
        className="q-select-trigger"
        aria-haspopup="listbox"
        aria-expanded={open}
        aria-controls={listId}
        onClick={() => setOpen((was) => !was)}
        onKeyDown={(event) => {
          if (event.key === "ArrowDown" || event.key === "ArrowUp") {
            event.preventDefault();
            if (!open) setOpen(true);
            else move(event.key === "ArrowDown" ? 1 : -1);
          }
          if (event.key === "Enter" && open) {
            event.preventDefault();
            choose(active);
          }
          if (event.key === "Escape") setOpen(false);
        }}
      >
        <span className="q-select-copy">
          <span className="q-select-kicker">
            <span className="q-pill">{selected.kicker}</span>
          </span>
          <span className="q-select-value">{selected.label}</span>
        </span>
        <span className="q-select-chevron" aria-hidden="true" />
      </button>
      {open && (
        <ul id={listId} className="q-select-menu" role="listbox" aria-label={label}>
          {options.map((item) => {
            const isSelected = item.id === value;
            const isActive = item.id === active;
            return (
              <li key={item.id} role="option" aria-selected={isSelected}>
                <button
                  type="button"
                  className={`q-select-option${isSelected ? " is-selected" : ""}${isActive ? " is-active" : ""}`}
                  onMouseEnter={() => setActive(item.id)}
                  onClick={() => choose(item.id)}
                >
                  <span className="q-select-option-top">
                    <span className="q-pill">{item.kicker}</span>
                    {isSelected && <span className="q-check" aria-hidden="true" />}
                  </span>
                  <span className="q-select-option-label">{item.label}</span>
                  <span className="q-select-option-proof">{item.proof}</span>
                </button>
              </li>
            );
          })}
        </ul>
      )}
    </div>
  );
}
