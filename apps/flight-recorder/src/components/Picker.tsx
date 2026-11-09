import { useEffect, useId, useRef, useState } from "react";

/** Dark-console listbox. Never a native select. Arrows, Enter, Escape. */
export function Picker({ options, value, onChange, width = 180 }: {
  options: { value: string; label: string }[];
  value: string;
  onChange: (value: string) => void;
  width?: number;
}) {
  const [open, setOpen] = useState(false);
  const [hi, setHi] = useState(Math.max(0, options.findIndex((option) => option.value === value)));
  const ref = useRef<HTMLDivElement>(null);
  const listId = useId();
  useEffect(() => {
    function outside(event: MouseEvent) {
      if (!ref.current?.contains(event.target as Node)) setOpen(false);
    }
    document.addEventListener("mousedown", outside);
    return () => document.removeEventListener("mousedown", outside);
  }, []);
  function onKey(event: React.KeyboardEvent) {
    if (event.key === "ArrowDown") {
      event.preventDefault();
      setOpen(true);
      setHi((index) => Math.min(options.length - 1, index + 1));
    } else if (event.key === "ArrowUp") {
      event.preventDefault();
      setOpen(true);
      setHi((index) => Math.max(0, index - 1));
    } else if (event.key === "Enter") {
      event.preventDefault();
      if (open) { onChange(options[hi].value); setOpen(false); }
      else setOpen(true);
    } else if (event.key === "Escape") setOpen(false);
  }
  const current = options.find((option) => option.value === value);
  return (
    <div ref={ref} className="picker" style={{ width }} onKeyDown={onKey}>
      <button type="button" className="picker-trigger" aria-haspopup="listbox" aria-expanded={open} aria-controls={listId} onClick={() => setOpen((was) => !was)}>
        <span>{current?.label ?? "–"}</span>
        <i className={open ? "up" : ""} aria-hidden="true">⌄</i>
      </button>
      {open && (
        <ul id={listId} className="picker-menu" role="listbox">
          {options.map((option, index) => (
            <li
              key={option.value}
              role="option"
              aria-selected={option.value === value}
              className={`${index === hi ? "hi" : ""} ${option.value === value ? "sel" : ""}`}
              onMouseEnter={() => setHi(index)}
              onClick={() => { onChange(option.value); setOpen(false); }}
            >
              {option.label}{option.value === value && <b>✓</b>}
            </li>
          ))}
        </ul>
      )}
    </div>
  );
}
