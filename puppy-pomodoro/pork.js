// Pork the dog — one drawing shared by the popup and the on-page window.
// Put PORK_SVG inside an <svg>, PORK_CSS in a <style>, and set data-pose on
// an ancestor: sleep | wait | pace | door | out.
// Pork faces right; his feet stand on y = 60.

var PORK_SVG = `
<g class="flip"><g class="pork">
  <g class="tail">
    <g class="tailEdge"><circle cx="15" cy="29" r="8"/><circle cx="9" cy="21" r="8.5"/><circle cx="11" cy="12" r="8"/><circle cx="19" cy="7" r="6.5"/><circle cx="26" cy="9" r="4.5"/></g>
    <g class="tailFill"><circle cx="15" cy="29" r="8"/><circle cx="9" cy="21" r="8.5"/><circle cx="11" cy="12" r="8"/><circle cx="19" cy="7" r="6.5"/><circle cx="26" cy="9" r="4.5"/></g>
  </g>
  <g class="legs back">
    <g class="leg legB1"><rect x="20" y="44" width="10" height="17" rx="5"/></g>
    <g class="leg legB2"><rect x="30" y="44" width="10" height="17" rx="5"/></g>
  </g>
  <ellipse class="haunch" cx="28" cy="50" rx="13" ry="11"/>
  <ellipse class="body" cx="44" cy="40" rx="30" ry="17"/>
  <path class="fluff" d="M18 46 q4 6 8 1 q4 6 8 1 q4 6 8 1 q4 6 8 1 q4 6 8 1 q4 5 8 0"/>
  <rect class="harness" x="38" y="23.5" width="24" height="19" rx="6"/>
  <rect class="harness strap" x="59" y="26" width="7" height="25" rx="3.5"/>
  <circle class="ring" cx="50" cy="27" r="2"/>
  <g class="legs front">
    <g class="leg legF1"><rect x="56" y="44" width="10" height="17" rx="5"/></g>
    <g class="leg legF2"><rect x="65" y="44" width="10" height="17" rx="5"/></g>
  </g>
  <g class="head">
    <circle class="fur" cx="80" cy="22" r="16"/>
    <circle class="fur" cx="74" cy="9" r="6"/><circle class="fur" cx="82" cy="7" r="6"/><circle class="fur" cx="89" cy="11" r="5"/>
    <circle class="eyeRim" cx="88" cy="19" r="4.6"/>
    <circle class="eye eyeOpen" cx="88" cy="19" r="2.8"/>
    <circle class="shine eyeOpen" cx="89" cy="18" r="0.9"/>
    <path class="eyeShut" d="M85 20 q3 2.6 6 0"/>
    <path class="brow" d="M82 13 q5 -3 10 1"/>
    <ellipse class="muzzle" cx="95" cy="28" rx="10.5" ry="8"/>
    <path class="beard" d="M90 33 l-1 6 M94 34 l0 6 M98 34 l1 5 M101 32 l3 4"/>
    <ellipse class="nose" cx="104" cy="25" rx="4" ry="3.3"/>
    <ellipse class="tongue" cx="97" cy="36.5" rx="2.6" ry="3.8"/>
    <ellipse class="ear" cx="71" cy="27" rx="7.5" ry="14" transform="rotate(12 71 27)"/>
    <path class="earLine" d="M69 18 q-2 9 1 19"/>
  </g>
</g></g>`;

var PORK_CSS = `
.pork .tailEdge circle { fill: #fbfbf8; stroke: #cfcfc9; stroke-width: 2.4; }
.pork .tailFill circle { fill: #fbfbf8; }
.pork .fur, .pork .body, .pork .haunch, .pork .leg rect {
  fill: #fbfbf8; stroke: #cfcfc9; stroke-width: 1.2; }
.pork .head .fur { stroke: none; }
.pork .head > .fur:first-child { stroke: #cfcfc9; stroke-width: 1.2; }
.pork .fluff { fill: none; stroke: #dcdcd6; stroke-width: 1.2; }
.pork .harness { fill: #22396b; }
.pork .ring { fill: #c9ccd6; }
.pork .ear { fill: #9c9c98; }
.pork .earLine { stroke: #c4c4bf; stroke-width: 1.4; fill: none; }
.pork .eyeRim { fill: #c9c9c3; }
.pork .eye { fill: #3a2418; }
.pork .shine { fill: #fff; }
.pork .eyeShut { stroke: #3a2418; stroke-width: 1.6; fill: none; stroke-linecap: round; display: none; }
.pork .brow { stroke: #e6e6e0; stroke-width: 2.4; fill: none; stroke-linecap: round; }
.pork .muzzle { fill: #f3f3ef; }
.pork .beard { stroke: #9a9a95; stroke-width: 1.2; stroke-linecap: round; }
.pork .nose { fill: #1d1d1d; }
.pork .tongue { fill: #ef7f92; display: none; }
.pork .haunch { display: none; }

.flip { transform-box: view-box; transform-origin: 55px 0; }
.pork { transform-box: view-box; transform-origin: 30px 60px; transition: transform .5s; }
.pork .head { transform-box: view-box; transform-origin: 74px 30px; transition: transform .5s; }
.pork .tail { transform-box: view-box; transform-origin: 18px 34px; animation: pk-wag .5s ease-in-out infinite alternate; }
.pork .leg { transform-box: fill-box; transform-origin: 50% 12%; }

@keyframes pk-wag { from { transform: rotate(-10deg); } to { transform: rotate(12deg); } }
@keyframes pk-walk { from { transform: rotate(-22deg); } to { transform: rotate(22deg); } }
@keyframes pk-bob { 0%, 100% { transform: translateY(0); } 50% { transform: translateY(-2.5px); } }
@keyframes pk-scratch { from { transform: rotate(-50deg); } to { transform: rotate(-100deg); } }
@keyframes pk-flip { 0%, 49.9% { transform: scaleX(1); } 50%, 100% { transform: scaleX(-1); } }
@keyframes pk-look { 0%, 70%, 100% { transform: rotate(-6deg); } 80%, 90% { transform: rotate(4deg); } }

/* napping on the bed */
[data-pose="sleep"] .pork { transform: translateY(6px) scaleY(.9); }
[data-pose="sleep"] .pork .legs, [data-pose="sleep"] .pork .strap { display: none; }
[data-pose="sleep"] .pork .eyeOpen { display: none; }
[data-pose="sleep"] .pork .eyeShut { display: inline; }
[data-pose="sleep"] .pork .tail { animation-duration: 2.4s; }

/* sitting in front of the door, staring outside */
[data-pose="wait"] .pork { transform: rotate(-18deg); }
[data-pose="wait"] .pork .back { display: none; }
[data-pose="wait"] .pork .haunch { display: inline; }
[data-pose="wait"] .pork .front .leg { transform: rotate(18deg); }
[data-pose="wait"] .pork .head { animation: pk-look 4s ease-in-out infinite; }
[data-pose="wait"] .pork .tail { animation-duration: 1.4s; }

/* walking back and forth */
[data-pose="pace"] .flip { animation: pk-flip 3.2s infinite; }
[data-pose="pace"] .pork, [data-pose="out"] .pork { animation: pk-bob .35s ease-in-out infinite; }
[data-pose="pace"] .pork .leg, [data-pose="out"] .pork .leg { animation: pk-walk .35s ease-in-out infinite alternate; }
[data-pose="pace"] .pork .legB2, [data-pose="pace"] .pork .legF1,
[data-pose="out"] .pork .legB2, [data-pose="out"] .pork .legF1 { animation-direction: alternate-reverse; }
[data-pose="pace"] .pork .tongue, [data-pose="out"] .pork .tongue { display: inline; }
[data-pose="pace"] .pork .tail, [data-pose="out"] .pork .tail { animation-duration: .2s; }

/* up on the back legs, scratching the door */
[data-pose="door"] .pork { transform: rotate(-42deg); }
[data-pose="door"] .pork .head { transform: rotate(30deg); }
[data-pose="door"] .pork .front .leg { animation: pk-scratch .26s ease-in-out infinite alternate; }
[data-pose="door"] .pork .legF2 { animation-direction: alternate-reverse; }
[data-pose="door"] .pork .tail { animation-duration: .16s; }
`;
