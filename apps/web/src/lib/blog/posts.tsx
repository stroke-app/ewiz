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
    <Prose>
      <p>
        Your Mac&apos;s battery is a consumable — it gets a little weaker every day, whether you use
        it or not. But that decline isn&apos;t on a fixed schedule. Two people with identical
        laptops can end up with wildly different battery health after two years, and the difference
        is almost entirely <strong>how the battery was treated</strong>. Here&apos;s what&apos;s
        actually happening inside the cell, what does the real damage, and the small set of habits
        that keep it healthy for years.
      </p>

      <h2>How a lithium-ion battery actually works</h2>
      <p>
        A lithium-ion cell has two electrodes: a <strong>graphite anode</strong> (the negative side)
        and a <strong>metal-oxide cathode</strong> (the positive side — usually a lithium compound
        like NMC or LCO). Between them sits a thin porous separator soaked in a liquid{" "}
        <strong>electrolyte</strong> that lithium ions can swim through but electrons cannot.
      </p>
      <p>
        Charging pushes lithium ions out of the cathode, across the electrolyte, and in between the
        graphite layers of the anode — a process called <strong>intercalation</strong>. The
        electrons take the long way around, through your charger and into the circuit. Discharging
        is just the reverse: the ions drift back to the cathode, and as they go they push electrons
        out through your Mac, which is the current that runs it.
      </p>
      <p>
        Nothing is burned or used up in a healthy cell — ions simply shuttle back and forth. The
        &ldquo;state of charge&rdquo; you see as a percentage is really how full the anode is, and
        the cell&apos;s voltage climbs as it fills: roughly 3.0&nbsp;V when empty to about
        4.2&nbsp;V when completely full. Hold that last number in your head, because it turns out to
        matter a lot.
      </p>

      <h2>The myth: it isn&apos;t about how many times you charge</h2>
      <p>
        Most people fixate on <strong>cycle count</strong> — the number of times they&apos;ve
        &ldquo;used up&rdquo; a full charge. Cycles do matter, but they&apos;re not the main story.
        A battery ages on two clocks at once: a <strong>cycle clock</strong> (wear from charging and
        discharging) and a <strong>calendar clock</strong> (chemistry that degrades simply with
        time). A laptop left full and warm in a drawer will lose health without completing a single
        cycle.
      </p>
      <p>
        Apple rates modern MacBook batteries for around 1,000 cycles to 80% of their original
        capacity — but real-world capacity loss is dominated less by that counter and far more by{" "}
        <strong>the conditions the battery lives in between charges</strong>. Which brings us to the
        thing that actually does the damage.
      </p>

      <h2>The real killer: a full battery that runs hot</h2>
      <Callout title="The crux">
        Two stressors dominate battery aging: <strong>a high state of charge</strong> (sitting near
        100%) and <strong>heat</strong>. Each is harmful on its own. Together they multiply. A
        laptop kept plugged in at 100% while it runs warm is close to the worst case — and it&apos;s
        exactly what most of us do all day.
      </Callout>
      <p>
        When a cell is near full, its cathode sits at a high voltage. High voltage is chemically
        aggressive: it slowly oxidizes the electrolyte and puts mechanical strain on the
        cathode&apos;s crystal structure. Heat then acts as an accelerant on every one of those
        reactions. So it&apos;s not charging that wears the battery so much as{" "}
        <strong>where you leave it parked, and how hot it gets while parked there</strong>.
      </p>

      <h2>The science under the hood</h2>
      <h3>The SEI layer</h3>
      <p>
        The first time a cell charges, a microscopically thin film called the{" "}
        <strong>solid electrolyte interphase</strong> (SEI) forms on the anode. It&apos;s actually
        necessary — it protects the graphite. But it never stops growing. Every bit of growth locks
        away a little lithium for good and adds internal resistance, which shows up as lost capacity
        and a battery that heats up more under load. High voltage and high temperature both speed
        that growth, and the added resistance makes more heat — a slow feedback loop.
      </p>
      <h3>Electrolyte oxidation and cathode wear</h3>
      <p>
        At high states of charge the electrolyte oxidizes at the cathode surface, and repeatedly
        swinging the cell between empty and full cracks the cathode particles and dissolves trace
        metals out of them. Both permanently remove active material. Shallow swings in the middle of
        the range are far gentler than deep, full-range cycles.
      </p>
      <h3>Lithium plating</h3>
      <p>
        If you charge too fast — or charge while the battery is cold — lithium can&apos;t slot into
        the graphite quickly enough and instead <strong>plates out as metallic lithium</strong> on
        the anode surface. That lithium is lost forever, and in the worst cases it forms structures
        that can short the cell. This is why charging a cold battery hard is one of the few things
        that can do sudden, permanent damage.
      </p>
      <h3>The Arrhenius rule</h3>
      <p>
        There&apos;s a useful rule of thumb from chemistry: reaction rates roughly{" "}
        <strong>double for every 10&nbsp;°C</strong> increase in temperature. A battery that
        habitually runs at 35&nbsp;°C is aging at something like twice the rate of one kept near
        25&nbsp;°C. Heat isn&apos;t a separate problem from the others — it multiplies all of them.
      </p>
      <h3>Voltage is the other dial</h3>
      <p>
        The single most effective lever is the maximum voltage you let the cell reach. Holding a
        battery to about 80% (roughly 4.0–4.1&nbsp;V) instead of a full 4.2&nbsp;V has been shown to{" "}
        <strong>multiply its usable lifespan several times over</strong>. You give up a little
        runtime today in exchange for a battery that still holds a real charge years from now.
      </p>

      <h2>How to actually make it last</h2>
      <ul>
        <li>
          <strong>Live in the middle.</strong> Keep it roughly between 20% and 80%. That mid-range
          is the low-stress zone where all the aging mechanisms above run slowest.
        </li>
        <li>
          <strong>Don&apos;t park at 100%.</strong> If you&apos;re plugged in all day, cap the
          charge. Top all the way up to 100% only right before you actually need the extra runtime,
          then let it drop back.
        </li>
        <li>
          <strong>Keep it cool.</strong> Heat is the accelerant. Don&apos;t charge in a closed bag,
          on a bed or couch that blocks the vents, or in a hot car.
        </li>
        <li>
          <strong>Avoid draining to 0%.</strong> Deep discharges are stressful; plug in before it
          gets critically low rather than routinely running it flat.
        </li>
        <li>
          <strong>Fast-charge in moderation, never cold.</strong> The occasional quick top-up is
          fine; frequent hot fast-charging — and any fast charging of a cold battery — is not.
        </li>
        <li>
          <strong>Store it half-full.</strong> If a device will sit unused for weeks, leave it
          around 50–60%, not full and not empty.
        </li>
      </ul>

      <h2>Where Battlify fits</h2>
      <p>
        Notice that the two habits that matter most — <strong>not sitting at 100%</strong> and{" "}
        <strong>not running hot</strong> — are exactly the two things that are hardest to do by
        hand, because they happen while you&apos;re not paying attention. Battlify automates them:
        it holds your charge at a limit you choose (with a buffer so the charger isn&apos;t clicking
        on and off), keeps enforcing that limit even while the lid is closed so macOS can&apos;t
        sneak you back to 100% overnight, and pauses charging when the battery gets too warm. It
        turns the science above into a setting you configure once and forget.
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
  );
}

export const POSTS: Post[] = [
  {
    slug: "how-lithium-ion-batteries-age",
    title: "The real reason your battery dies — and how to stop it",
    description:
      "How a lithium-ion cell actually works, what's really killing yours (hint: it isn't charge cycles), the chemistry behind the decline, and the handful of habits that add years to its life.",
    date: "2026-07-03",
    displayDate: "July 3, 2026",
    readingMinutes: 9,
    tag: "Battery science",
    Content: LithiumIonPost,
  },
];

export function getPost(slug: string): Post | undefined {
  return POSTS.find((p) => p.slug === slug);
}
