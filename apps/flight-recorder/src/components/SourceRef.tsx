interface Props {
  /** cos.db table or tables */
  table: string;
  /** the aggregate this visual reads */
  reads: string;
}

export function SourceRef({ table, reads }: Props) {
  const tip = `${table}: ${reads}`;
  return (
    <p className="source-ref">
      <span className="source-ref-label">Source</span>
      <code tabIndex={0} aria-label={`Source ${tip}`} data-tip={reads}>
        {table}
      </code>
    </p>
  );
}
