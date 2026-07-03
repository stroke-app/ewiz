/**
 * Long-form article styling without a typography plugin: descendant selectors
 * style plain <h2>/<p>/<ul>/<strong>/<a> written naturally inside <Prose>.
 */
export function Prose({ children }: { children: React.ReactNode }) {
  return (
    <div className="text-[15px] leading-7 text-muted-foreground [&>*:first-child]:mt-0 [&_a]:font-medium [&_a]:text-primary [&_a]:underline [&_a]:underline-offset-4 [&_code]:rounded [&_code]:bg-muted [&_code]:px-1.5 [&_code]:py-0.5 [&_code]:font-mono [&_code]:text-[13px] [&_code]:text-foreground [&_h2]:mt-12 [&_h2]:font-display [&_h2]:text-2xl [&_h2]:font-bold [&_h2]:tracking-tight [&_h2]:text-foreground [&_h3]:mt-8 [&_h3]:text-lg [&_h3]:font-semibold [&_h3]:text-foreground [&_li]:pl-1 [&_li]:marker:text-primary/60 [&_ol]:mt-5 [&_ol]:list-decimal [&_ol]:space-y-2 [&_ol]:pl-5 [&_p]:mt-5 [&_strong]:font-semibold [&_strong]:text-foreground [&_ul]:mt-5 [&_ul]:list-disc [&_ul]:space-y-2 [&_ul]:pl-5">
      {children}
    </div>
  );
}

/** Pull-quote / key-insight box used to spotlight the crux of an article. */
export function Callout({ title, children }: { title: string; children: React.ReactNode }) {
  return (
    <aside className="my-8 rounded-xl border border-primary/30 bg-primary/5 p-5">
      <p className="text-xs font-semibold tracking-[0.14em] text-primary uppercase">{title}</p>
      <div className="mt-2 text-[15px] leading-7 text-foreground [&_strong]:font-semibold">
        {children}
      </div>
    </aside>
  );
}
