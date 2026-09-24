// King & Queen of the Pacific — Judge Panel Prototype
// Shared static reference data — event/judge/round info, the contestant
// roster, and the scoring rubric structure. Nothing here is mutable at
// runtime; scores/notes/submission state live in state.js instead.
//
// Loaded as a plain global (window.JudgePrototypeData) rather than an ES
// module so every page can use a plain <script src> with no build step,
// consistent with the rest of this prototype.

(function () {
  // Scoring structure: sections with 1+ criteria. A section with a single
  // "standalone" criterion (Evening Gown, Stage Presence) shows its own
  // heading only — it is not a scorable parent on top of a scorable child.
  const scoringSections = [
    {
      heading: 'Interview',
      weight: 30,
      criteria: [
        { key: 'communication', label: 'Communication', weight: 10 },
        { key: 'confidence', label: 'Confidence', weight: 10, quickScore: [7, 8, 9, 10] },
        { key: 'substance', label: 'Substance', weight: 10 },
      ],
    },
    {
      heading: 'Evening Gown',
      weight: 30,
      criteria: [
        { key: 'eveningGown', label: 'Evening Gown', weight: 30, standalone: true },
      ],
    },
    {
      heading: 'Stage Presence',
      weight: 40,
      criteria: [
        { key: 'stagePresence', label: 'Stage Presence', weight: 40, standalone: true },
      ],
    },
  ];

  const criteriaList = scoringSections.reduce(function (list, section) {
    return list.concat(section.criteria);
  }, []);

  const criteriaKeys = criteriaList.map(function (c) { return c.key; });

  // name/country/photo transcribed directly from each contestant's supplied banner image.
  // Photo paths are relative to /pages/*.html, the only place they're rendered from.
  const contestants = [
    { id: 1, number: 1, name: 'Mrs Shaida', country: 'Malaysia', photo: '../assets/images/Miss 1.jpg' },
    { id: 2, number: 2, name: 'Mrs Beathres', country: 'Borneo Island, Malaysia', photo: '../assets/images/Miss 2.jpg' },
    { id: 3, number: 3, name: 'Mrs Baimar', country: 'Russia', photo: '../assets/images/Miss 3.jpg' },
    { id: 4, number: 4, name: 'Miss Evgeniya', country: 'Russia', photo: '../assets/images/Miss 4.jpg' },
    { id: 5, number: 5, name: 'Miss Nicole', country: 'Malaysia', photo: '../assets/images/Miss 5.jpg' },
    { id: 6, number: 6, name: 'Miss Yuka', country: 'Japan', photo: '../assets/images/Miss 6.jpg' },
    { id: 7, number: 7, name: 'Miss Park Jinah', country: 'Korea', photo: '../assets/images/Miss 7.jpg' },
    { id: 8, number: 8, name: 'Miss Lee Seoyul', country: 'Korea', photo: '../assets/images/Miss 8.jpg' },
    { id: 9, number: 9, name: 'Miss Veronika', country: 'Borneo Island, Indonesia', photo: '../assets/images/Miss 9.jpg' },
    { id: 10, number: 10, name: 'Miss Bolormaa', country: 'Mongolia', photo: '../assets/images/Miss 10.jpg' },
    { id: 11, number: 11, name: 'Mister Hady', country: 'Borneo Island, Indonesia', photo: '../assets/images/Mister 1.jpg' },
    { id: 12, number: 12, name: 'Mister Nicholas', country: 'Malaysia', photo: '../assets/images/Mister 2.jpg' },
    { id: 13, number: 13, name: 'Mister Azriq', country: 'Borneo Island, Brunei', photo: '../assets/images/Mister 3.jpg' },
    { id: 14, number: 14, name: 'Mrs Edelisa', country: 'Portugal', photo: '../assets/images/Mister 4.jpg' },
    { id: 15, number: 15, name: 'Mister Jerome', country: 'Philippines', photo: '../assets/images/Mister 5.jpg' },
  ];
  const seedPhotos = contestants.map(function (person) { return person.photo; });
  function judgePhotoPath(photo, contestantId) {
    const source = String(photo || '').trim();
    if (!source) return '';
    // Admin master paths are relative to admin/*.html; Judge pages live in pages/.
    const seedMatch = /^photos\/contestant-(\d{2})\.jpg$/i.exec(source);
    if (seedMatch && Number(seedMatch[1]) === Number(contestantId) && seedPhotos[contestantId - 1]) return seedPhotos[contestantId - 1];
    if (/^photos\//i.test(source)) return '../admin/' + source;
    if (/^assets\//i.test(source)) return '../' + source;
    return source; // Existing ../assets/, data:, blob:, and absolute URLs already resolve.
  }

  // A few pre-filled demo scores so Gallery/Review filters have something to
  // show on first load (seeded into state.js on first run only). Everything
  // else starts genuinely empty (null) — a judge must enter every score
  // intentionally, never a silently-assumed default.
  const demoScores = {
    1: { communication: 8.75, confidence: 9.00, substance: 8.50, eveningGown: 9.25, stagePresence: 9.00 },
    2: { communication: 8.50, confidence: 8.75, substance: 8.75, eveningGown: 9.00, stagePresence: 8.75 },
    3: { communication: 8.00, confidence: 8.25, substance: 7.75, eveningGown: null, stagePresence: null },
    6: { communication: 9.00, confidence: 9.25, substance: 9.00, eveningGown: 9.50, stagePresence: 9.25 },
    8: { communication: 7.75, confidence: 8.00, substance: null, eveningGown: null, stagePresence: null },
  };

  // Fallback hues (used only if a photo fails to load) — jewel tones matching the royal palette.
  const photoHues = [345, 38, 275, 8, 25, 155, 320, 50, 300, 15, 165, 260, 335, 60, 200];

  // Title prefixes on the banners aren't part of the person's name — strip them before
  // computing initials so the photo-fallback monogram reads naturally (e.g. "Shaida" -> "S").
  const nameTitles = ['mrs', 'miss', 'mister'];

  const roundCriteria = {
    1: scoringSections,
    2: [
      { heading: 'Performance', weight: 60, criteria: [{ key: 'interview', label: 'Interview', weight: 30 }, { key: 'stagePresence', label: 'Stage Presence', weight: 30 }] },
      { heading: 'Presentation', weight: 40, criteria: [{ key: 'eveningGown', label: 'Evening Gown', weight: 40, standalone: true }] },
    ],
    3: [
      { heading: 'Final Assessment', weight: 100, criteria: [{ key: 'finalQuestion', label: 'Final Question', weight: 40 }, { key: 'overallImpression', label: 'Overall Impression', weight: 60, standalone: true }] },
    ],
  };
  const roundContestantIds = {
    1: contestants.map(function (c) { return c.id; }),
    2: contestants.slice(0, 10).map(function (c) { return c.id; }),
    3: contestants.slice(0, 5).map(function (c) { return c.id; }),
  };
  const rounds = [
    { id: 1, name: 'Preliminary', status: 'open', contestantIds: roundContestantIds[1], criteriaSections: roundCriteria[1], resultsVisibleToJudges: false },
    { id: 2, name: 'Top 10', status: 'draft', contestantIds: roundContestantIds[2], criteriaSections: roundCriteria[2], resultsVisibleToJudges: false },
    { id: 3, name: 'Final', status: 'draft', contestantIds: roundContestantIds[3], criteriaSections: roundCriteria[3], resultsVisibleToJudges: false },
  ];
  // The Admin prototype owns operational round status; this is a local demo bridge.
  try {
    const config = JSON.parse(localStorage.getItem('kreenAdminConfiguration') || '{}');
    if (Array.isArray(config.contestants)) config.contestants.forEach(function (master) { const person = contestants.find(function (item) { return item.id === Number(master.id); }); if (person) { person.name = master.name; person.country = master.country; if (master.photoCleared) person.photo = ''; else if (master.photo) person.photo = judgePhotoPath(master.photo, person.id); } });
    const criterionKeys = { 'evening-gown': 'eveningGown', 'stage-presence': 'stagePresence', 'final-question': 'finalQuestion', 'overall-impression': 'overallImpression' };
    rounds.forEach(function (round) { if (config.roundStatusById && config.roundStatusById[round.id]) round.status = config.roundStatusById[round.id]; round.resultsVisibleToJudges = !!(config.resultVisibilityByRound && config.resultVisibilityByRound[round.id]); });
    rounds.forEach(function (round) {
      if (config.contestantAssignments && Array.isArray(config.contestantAssignments[round.id])) round.contestantIds = config.contestantAssignments[round.id].map(Number);
      if (config.criteriaByRound && Array.isArray(config.criteriaByRound[round.id])) {
        const items = config.criteriaByRound[round.id].slice().sort(function (a, b) { return a.sequence - b.sequence; });
        const sections = [];
        items.forEach(function (item) { if (!item.isScored || item.isParent) { if (item.isParent) sections.push({ heading: item.name, weight: 0, parentId: item.id, criteria: [] }); return; } const criterion = { key: criterionKeys[item.id] || item.id, label: item.name, weight: Number(item.weight), standalone: !item.parentId }; let section = item.parentId && sections.find(function (entry) { return String(entry.parentId) === String(item.parentId); }); if (!section) { section = { heading: item.name, weight: 0, criteria: [] }; sections.push(section); } section.criteria.push(criterion); section.weight += criterion.weight; });
        if (sections.length) round.criteriaSections = sections;
      }
    });
  } catch (e) {}
  rounds.forEach(function (round) {
    round.criteriaList = round.criteriaSections.reduce(function (list, section) { return list.concat(section.criteria); }, []);
    round.criteriaKeys = round.criteriaList.map(function (criterion) { return criterion.key; });
  });

  window.JudgePrototypeData = {
    event: { name: 'King & Queen of the Pacific', year: 2026, logo: '../assets/images/kqp-logo.png' },
    judge: { number: 3, name: 'Amanda Wijaya' },
    round: { name: 'Preliminary' },
    rounds: rounds,
    getRound: function (id) { return rounds.find(function (round) { return round.id === Number(id); }) || null; },
    getRoundContestants: function (id) { const round = rounds.find(function (item) { return item.id === Number(id); }); return round ? round.contestantIds.map(function (contestantId) { return contestants.find(function (contestant) { return contestant.id === contestantId; }); }).filter(Boolean) : []; },
    getRoundCriteria: function (id) { const round = rounds.find(function (item) { return item.id === Number(id); }); return round ? round.criteriaList : []; },
    getRoundSections: function (id) { const round = rounds.find(function (item) { return item.id === Number(id); }); return round ? round.criteriaSections : []; },
    scoringSections: scoringSections,
    criteriaList: criteriaList,
    criteriaKeys: criteriaKeys,
    contestants: contestants,
    demoScores: demoScores,
    photoHues: photoHues,
    nameTitles: nameTitles,
    scoreMin: 1,
    scoreMax: 10,
    scoreStep: 0.25,
  };
})();
