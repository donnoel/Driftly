---
layout: default
title: Driftly
---

<section class="hero" aria-labelledby="hero-title">
  <div class="hero__copy">
    <p class="eyebrow">iPhone + iPad + Apple TV <span aria-hidden="true">·</span> Ambient motion</p>
    <h1 id="hero-title">Turn a screen into atmosphere.</h1>
    <p class="hero__lede">Driftly is a fullscreen liquid lamp made from cosmic gradients, slow generative motion, and controls quiet enough to disappear.</p>
    <div class="hero__actions">
      <a class="button button--primary" href="{{ site.github_url }}">View on GitHub <span aria-hidden="true">↗</span></a>
      <a class="button button--quiet" href="#drift-flow">See how it drifts</a>
    </div>
    <ul class="signal-list" aria-label="Project foundation">
      <li>SwiftUI</li>
      <li>Canvas</li>
      <li>iOS + tvOS</li>
      <li>Reduce Motion</li>
    </ul>
  </div>

  <aside class="status-card" aria-labelledby="build-status-title">
    <div class="status-card__topline">
      <span class="status-pill"><span class="status-dot" aria-hidden="true"></span>{{ site.status_label }}</span>
      <span class="status-card__meta">Ambient object</span>
    </div>
    <div class="house-mark" aria-hidden="true">
      <span></span><span></span><span></span><span></span>
    </div>
    <p class="status-card__kicker">Current experience</p>
    <h2 id="build-status-title">Slow down the screen.<br>Change the feeling of the room.</h2>
    <dl class="status-list">
      <div><dt>Ambient modes</dt><dd>Curated</dd></div>
      <div><dt>Auto Drift</dt><dd>Optional</dd></div>
      <div><dt>Saved scenes</dt><dd>Ready</dd></div>
    </dl>
  </aside>
</section>

<section class="section" aria-labelledby="principles-title">
  <div class="section-heading">
    <p class="eyebrow">Designed to be left on</p>
    <h2 id="principles-title">Motion can be present without asking for attention.</h2>
    <p>Driftly behaves more like a light object than a utility: the visuals fill the room, the chrome fades away, and every transition protects the calm.</p>
  </div>

  <div class="principle-grid">
    <article class="principle-card">
      <span class="card-number" aria-hidden="true">01</span>
      <h3>Fullscreen by nature</h3>
      <p>Liquid color, abstract lines, and generative fields take over the display while compact controls stay out of the composition.</p>
    </article>
    <article class="principle-card">
      <span class="card-number" aria-hidden="true">02</span>
      <h3>Continuous by design</h3>
      <p>Phase-stable animation and stacked crossfades keep motion coherent through pauses, backgrounding, and mode changes.</p>
    </article>
    <article class="principle-card">
      <span class="card-number" aria-hidden="true">03</span>
      <h3>Personal without clutter</h3>
      <p>Favorite modes, arrange the gallery, save named scenes, and optionally let Auto Drift move through a chosen collection.</p>
    </article>
  </div>
</section>

<section class="section section--split" id="drift-flow" aria-labelledby="scene-title">
  <article class="resident-card">
    <div class="resident-card__header">
      <div class="resident-icon" aria-hidden="true">
        <span></span><span></span><span></span>
      </div>
      <div>
        <p class="eyebrow">One saved scene</p>
        <h2 id="scene-title">A mood you can return to</h2>
      </div>
    </div>
    <p class="resident-card__summary">A scene keeps a selected set of modes and the settings that shape them together, ready for a nightstand, iPad dock, or television.</p>
    <div class="boundary-note">
      <strong>Built for different rooms</strong>
      <span>iPhone · iPad · Apple TV</span>
    </div>
    <ul class="capability-list">
      <li><span aria-hidden="true">✓</span> Curated liquid and generative modes</li>
      <li><span aria-hidden="true">✓</span> Edge gestures for in-app brightness</li>
      <li><span aria-hidden="true">✓</span> Optional motion parallax</li>
      <li><span aria-hidden="true">✓</span> Sleep timer for a gentle finish</li>
    </ul>
  </article>

  <div class="run-flow" aria-labelledby="flow-title">
    <p class="eyebrow">The ambient loop</p>
    <h2 id="flow-title">Choose the feeling. Let the interface leave.</h2>
    <ol>
      <li><span>01</span><div><strong>Choose a mode</strong><p>Start with one visual composition.</p></div></li>
      <li><span>02</span><div><strong>Tune the light</strong><p>Adjust brightness from the screen edge.</p></div></li>
      <li><span>03</span><div><strong>Hide the chrome</strong><p>Let the controls fade from view.</p></div></li>
      <li><span>04</span><div><strong>Save a scene</strong><p>Keep the combination for later.</p></div></li>
      <li><span>05</span><div><strong>Drift optionally</strong><p>Cycle through all, favorites, or a scene.</p></div></li>
      <li><span>06</span><div><strong>Settle the room</strong><p>Leave the motion running—or set a timer.</p></div></li>
    </ol>
  </div>
</section>

<section class="section foundation" aria-labelledby="foundation-title">
  <div>
    <p class="eyebrow">Smoothness is the product</p>
    <h2 id="foundation-title">Every frame has to hold the illusion.</h2>
  </div>
  <p>Driftly drives its Canvas modes from stable timeline phases, prewarms transitions instead of drawing blank frames, and treats tvOS frame pacing as first-class. Reduce Motion is respected throughout, and favorites sync through iCloud key-value storage.</p>
</section>
