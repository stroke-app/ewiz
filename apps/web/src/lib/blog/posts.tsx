import { AgingExplorer } from "#/components/blog/viz/aging-explorer";
import { CellDiagram } from "#/components/blog/viz/cell-diagram";
import { ChargeVoltage } from "#/components/blog/viz/charge-voltage";
import { Callout, Prose } from "#/components/prose";

export interface Post {
  slug: string;
  title: string;
  description: string;
  /** Machine date (ISO) for ordering. */
  date: string;
  /** Human date shown on the page. */
  displayDate: string;
  readingMinutes: number;
  tag: string;
  Content: () => React.ReactElement;
}

function LithiumIonPost() {
  return (
    <>
      <Prose>
        <p>
          Your Mac&apos;s battery is a consumable — it gets a little weaker every day, whether you
          use it or not. But that decline isn&apos;t on a fixed schedule. Two people with identical
          laptops can end up with wildly different battery health after two years, and the
          difference is almost entirely <strong>how the battery was treated</strong>.
        </p>
        <p>
          To see why, it helps to watch what&apos;s actually moving inside the cell. Press{" "}
          <strong>Charge</strong> and <strong>Discharge</strong> below.
        </p>
      </Prose>

      <CellDiagram />

      <Prose>
        <h2>How a lithium-ion battery actually works</h2>
        <p>
          Every cell has two electrodes — a <strong>graphite anode</strong> on the left and a{" "}
          <strong>metal-oxide cathode</strong> on the right — with a liquid{" "}
          <strong>electrolyte</strong> between them that lithium ions can swim through but electrons
          cannot.
        </p>
        <p>
          When you charge, lithium ions leave the cathode, drift across the electrolyte, and slot in
          between the graphite layers of the anode — a process called{" "}
          <strong>intercalation</strong> (that&apos;s the filling animation above). The electrons
          can&apos;t take the shortcut through the electrolyte, so they take the long way around,
          through your charger and the circuit. Discharge is the exact reverse: the ions flow back
          to the cathode, and as they go they push electrons out through your Mac — that current is
          what runs it.
        </p>
        <p>
          Nothing is burned or consumed in a healthy cell; ions just shuttle back and forth. The
          percentage you watched climb is really <strong>how full the anode is</strong> — and here
          is the part that matters most: the cell&apos;s voltage rises as it fills, from about
          3.0&nbsp;V empty to 4.2&nbsp;V full. Drag the charge level below to see the whole curve.
        </p>
      </Prose>

      <ChargeVoltage />

      <Prose>
        <p>
          Notice how flat the middle is, and how the curve rears up at the very top. That last
          stretch above ~80% — roughly 4.0&nbsp;V to 4.2&nbsp;V — is where the damage accelerates.
          Hold that thought.
        </p>

        <h2>The myth: it isn&apos;t about how many times you charge</h2>
        <p>
          Most people fixate on <strong>cycle count</strong>. Cycles do matter, but a battery ages
          on two clocks at once: a <strong>cycle clock</strong> (wear from charging and
          discharging) and a <strong>calendar clock</strong> (chemistry that degrades with time
          alone). A laptop left full and warm in a drawer loses health without completing a single
          cycle.
        </p>
        <p>
          Apple rates modern MacBook batteries for around 1,000 cycles to 80% capacity — but
          real-world loss is dominated far less by that counter and far more by{" "}
          <strong>the conditions the battery sits in between charges</strong>. There are two that do
          almost all the damage.
        </p>

        <h2>The real killer: a full battery that runs hot</h2>
        <p>
          The two stressors are <strong>a high state of charge</strong> and <strong>heat</strong>.
          Each is corrosive alone. Together they don&apos;t add — they multiply. The explorer below
          lets you feel it: set a charge ceiling and a temperature, and watch the projected battery
          health two years out.
        </p>
      </Prose>

      <AgingExplorer />

      <Callout title="The crux">
        A high charge level and heat <strong>multiply</strong> each other. The worst thing you can
        do is keep the battery pinned at 100% while it runs warm — which is exactly what a laptop
        left on a charger all day, or sealed warm in a bag, does for hours at a time.
      </Callout>

      <Prose>
        <h2>The science under the hood</h2>
        <h3>The SEI layer</h3>
        <p>
          The first time a cell charges, a microscopically thin film — the{" "}
          <strong>solid electrolyte interphase</strong> (SEI) — forms on the anode. It&apos;s
          actually necessary; it protects the graphite. But it never stops growing. Each bit of
          growth locks away a little lithium for good and raises internal resistance, which shows up
          as lost capacity and a battery that heats up more under load. High voltage and heat both
          speed that growth — and the added resistance makes more heat, a slow feedback loop.
        </p>
        <h3>Electrolyte oxidation and cathode wear</h3>
        <p>
          Near full charge the electrolyte oxidizes at the cathode surface, and repeatedly swinging
          the cell between empty and full cracks the cathode particles and leaches metals out of
          them. Both permanently remove active material. Shallow swings in the middle of the range
          are far gentler than deep, full-range cycles.
        </p>
        <h3>Lithium plating</h3>
        <p>
          Charge too fast — or charge while the battery is cold — and lithium can&apos;t slot into
          the graphite quickly enough. Instead it <strong>plates out as metallic lithium</strong> on
          the surface. That lithium is lost forever, and in the worst case it forms structures that
          can short the cell. This is why hammering a cold battery with a fast charger is one of the
          few things that does sudden, permanent damage.
        </p>
        <h3>The Arrhenius rule</h3>
        <p>
          There&apos;s a rule of thumb from chemistry: reaction rates roughly{" "}
          <strong>double for every 10&nbsp;°C</strong>. That&apos;s exactly the temperature slider in
          the explorer — nudge it from 25&nbsp;°C to 35&nbsp;°C and the aging rate doubles. Heat
          isn&apos;t a separate problem from the others; it multiplies all of them at once.
        </p>

        <h2>How to actually make it last</h2>
        <ul>
          <li>
            <strong>Live in the middle.</strong> Keep it roughly between 20% and 80% — the
            low-stress zone where every mechanism above runs slowest.
          </li>
          <li>
            <strong>Don&apos;t park at 100%.</strong> If you&apos;re plugged in all day, cap the
            charge. Top all the way up only right before you need the extra runtime.
          </li>
          <li>
            <strong>Keep it cool.</strong> Heat is the accelerant. Don&apos;t charge in a closed
            bag, on a bed or couch that blocks the vents, or in a hot car.
          </li>
          <li>
            <strong>Avoid draining to 0%.</strong> Deep discharges are stressful; plug in before
            it&apos;s critically low rather than routinely running it flat.
          </li>
          <li>
            <strong>Fast-charge in moderation, never cold.</strong> The occasional quick top-up is
            fine; frequent hot fast-charging — and any fast charging of a cold pack — is not.
          </li>
          <li>
            <strong>Store it half-full.</strong> Sitting unused for weeks? Leave it near 50–60%, not
            full and not empty.
          </li>
        </ul>

        <h2>Where Battlify fits</h2>
        <p>
          The two habits that matter most — <strong>not sitting at 100%</strong> and{" "}
          <strong>not running hot</strong> — are exactly the ones that are hardest to do by hand,
          because they happen while you&apos;re not watching. Battlify automates them: it holds your
          charge at a ceiling you pick (with a buffer so the charger isn&apos;t clicking on and off),
          keeps enforcing that ceiling even while the lid is closed so macOS can&apos;t sneak you
          back to 100% overnight, and pauses charging when the battery gets too warm. It turns
          everything above into a setting you configure once and forget.
        </p>

        <h2>Further reading</h2>
        <ul>
          <li>
            Battery University —{" "}
            <a
              href="https://batteryuniversity.com/article/bu-808-how-to-prolong-lithium-based-batteries"
              target="_blank"
              rel="noreferrer"
            >
              BU-808: How to Prolong Lithium-Based Batteries
            </a>
          </li>
          <li>
            Battery University —{" "}
            <a
              href="https://batteryuniversity.com/article/bu-808b-what-causes-li-ion-to-die"
              target="_blank"
              rel="noreferrer"
            >
              BU-808b: What Causes Li-ion to Die?
            </a>
          </li>
        </ul>
      </Prose>
    </>
  );
}

export const POSTS: Post[] = [
  {
    slug: "how-lithium-ion-batteries-age",
    title: "The real reason your battery dies — and how to stop it",
    description:
      "An interactive tour of the lithium-ion cell: how it works, what really wears it out (hint: it isn't charge cycles), the chemistry behind the decline, and the habits that add years to its life.",
    date: "2026-07-03",
    displayDate: "July 3, 2026",
    readingMinutes: 11,
    tag: "Battery science",
    Content: LithiumIonPost,
  },
];

export function getPost(slug: string): Post | undefined {
  return POSTS.find((p) => p.slug === slug);
}
