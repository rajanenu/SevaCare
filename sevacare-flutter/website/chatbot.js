/* SevaCare Assistant — self-contained chat widget for the marketing site.
 * Mirrors the in-app FAQ bot: offline, rule-based, no network/LLM. Injects its
 * own styles and markup so index.html only needs a single <script> tag. */
(function () {
  'use strict';

  // Public knowledge base (general + patient-facing). Kept in sync with the
  // app's "everyone" FAQ entries; onboarding/doctor answers stay authorised-only.
  var FAQ = [
    {
      q: 'Who are you?',
      a: "I'm the SevaCare Assistant 🤖 — a quick helper on this page. I can answer common questions about SevaCare, booking appointments, tokens and onboarding. Ask me anything, or tap a suggestion below.",
      k: ['who', 'you', 'your name', 'assistant', 'bot', 'yourself']
    },
    {
      q: 'What is SevaCare?',
      a: 'SevaCare is an end-to-end healthcare platform that connects hospital admins, doctors, staff and patients in one place — appointments, live token queues, prescriptions and records, all in a single app.',
      k: ['what', 'sevacare', 'about', 'app', 'platform', 'do', 'product']
    },
    {
      q: 'How can you help me?',
      a: 'I can explain how booking works, what a token is, how hospitals get onboarded, and how to reach the team. For anything specific, use the Contact section on this page and we\'ll get back to you.',
      k: ['help', 'how', 'support', 'assist', 'can you']
    },
    {
      q: 'How do I onboard my hospital?',
      a: 'Onboarding a hospital is handled by the SevaCare team, not self-service. An authorised representative of the hospital reaches out via the Contact section below, and our platform team reviews and sets everything up. Once live, your hospital admin can add doctors, staff and services.',
      k: ['onboard', 'register', 'hospital', 'sign up', 'signup', 'new hospital', 'setup', 'join', 'partner']
    },
    {
      q: 'How do patients book an appointment?',
      a: 'In the SevaCare app, a patient finds their hospital/doctor, picks a date and either a time slot or a token, then confirms. They get a token number and can track their position live in the queue.',
      k: ['book', 'appointment', 'booking', 'schedule', 'consult', 'visit', 'patient']
    },
    {
      q: 'What is a token?',
      a: 'A token is a patient\'s place in the doctor\'s queue for a session (morning/evening). A live board shows who is "Now Serving" so patients know when their turn is near — no crowding at the desk.',
      k: ['token', 'queue', 'number', 'turn', 'position', 'waiting', 'live']
    },
    {
      q: 'Can I add doctors or staff myself?',
      a: 'Adding doctors, staff and admins is a hospital-admin-only task inside the app — done by the hospital\'s own admin after onboarding. Doctors, staff and patients can\'t create these accounts themselves.',
      k: ['add', 'doctor', 'staff', 'admin', 'register doctor', 'create user', 'invite']
    },
    {
      q: 'Is my data safe?',
      a: 'Yes. Health information is stored securely and only visible to the patient and their care team at the hospital. We never sell your data.',
      k: ['data', 'safe', 'privacy', 'secure', 'security', 'private']
    },
    {
      q: 'How do I contact the team?',
      a: 'Head to the Contact section on this page — you\'ll find how to reach us. An authorised hospital representative can start the onboarding conversation there.',
      k: ['contact', 'reach', 'email', 'phone', 'talk', 'team', 'demo']
    }
  ];

  var GREETING = "Hi! I'm the SevaCare Assistant. Ask me about the platform, booking or onboarding — or tap a question below.";
  var FALLBACK = "I'm not sure about that one yet. For anything specific, please use the Contact section on this page and the team will help you out.";
  var SUGGESTIONS = ['What is SevaCare?', 'How do I onboard my hospital?', 'What is a token?', 'Is my data safe?'];

  function match(input) {
    var text = input.toLowerCase();
    var best = null, bestScore = 0;
    for (var i = 0; i < FAQ.length; i++) {
      var e = FAQ[i];
      if (text.indexOf(e.q.toLowerCase()) !== -1) return e; // exact-ish question
      var score = 0;
      for (var j = 0; j < e.k.length; j++) {
        if (text.indexOf(e.k[j]) !== -1) score++;
      }
      if (score > bestScore) { bestScore = score; best = e; }
    }
    return bestScore >= 2 ? best : null;
  }

  var STYLE = [
    '.sc-chat-fab{position:fixed;right:20px;bottom:20px;width:56px;height:56px;border:none;border-radius:50%;',
    'background:linear-gradient(135deg,#5148CC,#3F39A8);color:#fff;cursor:pointer;z-index:9998;',
    'box-shadow:0 8px 24px rgba(81,72,204,.4);display:flex;align-items:center;justify-content:center;transition:transform .15s ease}',
    '.sc-chat-fab:hover{transform:scale(1.06)}',
    '.sc-chat-fab svg{width:26px;height:26px}',
    '.sc-chat-panel{position:fixed;right:20px;bottom:88px;width:360px;max-width:calc(100vw - 32px);height:520px;max-height:calc(100vh - 120px);',
    'background:#fff;border:1px solid #E7E7F2;border-radius:18px;box-shadow:0 20px 60px rgba(26,27,46,.25);',
    'z-index:9999;display:none;flex-direction:column;overflow:hidden;font-family:inherit}',
    '.sc-chat-panel.open{display:flex;animation:sc-pop .18s ease}',
    '@keyframes sc-pop{from{opacity:0;transform:translateY(12px)}to{opacity:1;transform:none}}',
    '.sc-chat-head{background:linear-gradient(135deg,#5148CC,#3F39A8);color:#fff;padding:14px 16px;display:flex;align-items:center;gap:10px}',
    '.sc-chat-head .sc-dot{width:36px;height:36px;border-radius:50%;background:rgba(255,255,255,.18);display:flex;align-items:center;justify-content:center}',
    '.sc-chat-head b{font-size:15px;display:block}.sc-chat-head small{opacity:.85;font-size:12px}',
    '.sc-chat-close{margin-left:auto;background:none;border:none;color:#fff;font-size:22px;cursor:pointer;line-height:1;opacity:.9}',
    '.sc-chat-body{flex:1;overflow-y:auto;padding:16px;background:#F7F7FB;display:flex;flex-direction:column;gap:10px}',
    '.sc-msg{max-width:82%;padding:10px 13px;border-radius:14px;font-size:14px;line-height:1.45;white-space:pre-wrap}',
    '.sc-msg.bot{background:#fff;border:1px solid #E7E7F2;color:#1A1B2E;align-self:flex-start;border-bottom-left-radius:4px}',
    '.sc-msg.user{background:#5148CC;color:#fff;align-self:flex-end;border-bottom-right-radius:4px}',
    '.sc-chips{display:flex;flex-wrap:wrap;gap:8px;padding:0 16px 12px;background:#F7F7FB}',
    '.sc-chip{background:#EEEEFF;color:#3F39A8;border:none;border-radius:999px;padding:7px 12px;font-size:12.5px;cursor:pointer;font-family:inherit}',
    '.sc-chip:hover{background:#e0e0ff}',
    '.sc-chat-input{display:flex;gap:8px;padding:12px;border-top:1px solid #E7E7F2;background:#fff}',
    '.sc-chat-input input{flex:1;border:1px solid #E7E7F2;border-radius:999px;padding:10px 14px;font-size:14px;outline:none;font-family:inherit}',
    '.sc-chat-input input:focus{border-color:#5148CC}',
    '.sc-chat-input button{background:linear-gradient(135deg,#5148CC,#3F39A8);color:#fff;border:none;border-radius:50%;width:40px;height:40px;cursor:pointer;flex:none;font-size:16px}'
  ].join('');

  function el(tag, cls, html) {
    var e = document.createElement(tag);
    if (cls) e.className = cls;
    if (html != null) e.innerHTML = html;
    return e;
  }

  function init() {
    var style = el('style'); style.textContent = STYLE; document.head.appendChild(style);

    var fab = el('button', 'sc-chat-fab');
    fab.setAttribute('aria-label', 'Chat with the SevaCare Assistant');
    fab.innerHTML = '<svg viewBox="0 0 24 24" fill="currentColor"><path d="M12 2a10 10 0 0 0-8.94 14.47L2 22l5.66-1.05A10 10 0 1 0 12 2zm-4 9a1.25 1.25 0 1 1 0-2.5A1.25 1.25 0 0 1 8 11zm4 0a1.25 1.25 0 1 1 0-2.5A1.25 1.25 0 0 1 12 11zm4 0a1.25 1.25 0 1 1 0-2.5A1.25 1.25 0 0 1 16 11z"/></svg>';

    var panel = el('div', 'sc-chat-panel');
    panel.setAttribute('role', 'dialog');
    panel.setAttribute('aria-label', 'SevaCare Assistant');

    var head = el('div', 'sc-chat-head',
      '<span class="sc-dot"><svg width="20" height="20" viewBox="0 0 24 24" fill="#fff"><path d="M12 2a10 10 0 0 0-8.94 14.47L2 22l5.66-1.05A10 10 0 1 0 12 2z"/></svg></span>' +
      '<span><b>SevaCare Assistant</b><small>Typically replies instantly</small></span>');
    var close = el('button', 'sc-chat-close', '&times;');
    close.setAttribute('aria-label', 'Close chat');
    head.appendChild(close);

    var body = el('div', 'sc-chat-body');
    var chips = el('div', 'sc-chips');
    var inputRow = el('div', 'sc-chat-input');
    var input = el('input');
    input.type = 'text'; input.placeholder = 'Type your question…';
    var send = el('button', null, '&#10148;');
    send.setAttribute('aria-label', 'Send');
    inputRow.appendChild(input); inputRow.appendChild(send);

    panel.appendChild(head); panel.appendChild(body); panel.appendChild(chips); panel.appendChild(inputRow);
    document.body.appendChild(fab); document.body.appendChild(panel);

    function addMsg(text, who) {
      var m = el('div', 'sc-msg ' + who, text.replace(/&/g, '&amp;').replace(/</g, '&lt;'));
      body.appendChild(m); body.scrollTop = body.scrollHeight;
    }
    function renderChips() {
      chips.innerHTML = '';
      SUGGESTIONS.forEach(function (q) {
        var c = el('button', 'sc-chip', q);
        c.onclick = function () { ask(q); };
        chips.appendChild(c);
      });
    }
    function ask(text) {
      text = (text || '').trim(); if (!text) return;
      addMsg(text, 'user'); input.value = '';
      var hit = match(text);
      setTimeout(function () { addMsg(hit ? hit.a : FALLBACK, 'bot'); }, 250);
    }

    var opened = false;
    function open() {
      panel.classList.add('open');
      if (!opened) { addMsg(GREETING, 'bot'); renderChips(); opened = true; }
      input.focus();
    }
    function closePanel() { panel.classList.remove('open'); }

    fab.onclick = function () { panel.classList.contains('open') ? closePanel() : open(); };
    close.onclick = closePanel;
    send.onclick = function () { ask(input.value); };
    input.addEventListener('keydown', function (e) { if (e.key === 'Enter') ask(input.value); });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', init);
  } else {
    init();
  }
})();
