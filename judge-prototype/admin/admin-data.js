// KREEN Judging — Admin Operational Core mock source (Phase 2).
// Local structured data only: no API, persistence, auth, or Judge Mode access.
(function () {
  const rounds = [
    { id: 1, order: 1, name: 'Preliminary', status: 'open', contestants: 15, judges: 7, criteria: 5, advancementCount: 10 },
    { id: 2, order: 2, name: 'Top 10', status: 'draft', contestants: 10, judges: 7, criteria: 4, advancementCount: 5 },
    { id: 3, order: 3, name: 'Final', status: 'draft', contestants: 5, judges: 9, criteria: 3, advancementCount: null }
  ];

  const judgesByRound = {
    1: [
      { id: 1, number: 'Judge 01', name: 'Ratih Pramesti', completed: 15, total: 15, submissionStatus: 'submitted', connection: 'online', lastSync: '21:41' },
      { id: 2, number: 'Judge 02', name: 'Dimas Ardiansyah', completed: 15, total: 15, submissionStatus: 'submitted', connection: 'syncing', lastSync: '21:40' },
      { id: 3, number: 'Judge 03', name: 'Amanda Wijaya', completed: 15, total: 15, submissionStatus: 'submitted', connection: 'online', lastSync: '21:39' },
      { id: 4, number: 'Judge 04', name: 'Budi Santoso', completed: 12, total: 15, submissionStatus: 'in-progress', connection: 'offline', lastSync: '21:34' },
      { id: 5, number: 'Judge 05', name: 'Maria Tan', completed: 0, total: 15, submissionStatus: 'not-started', connection: 'online', lastSync: '21:28' },
      { id: 6, number: 'Judge 06', name: 'Kevin Mahendra', completed: 15, total: 15, submissionStatus: 'submitted', connection: 'online', lastSync: '21:37' },
      { id: 7, number: 'Judge 07', name: 'Sari Handayani', completed: 15, total: 15, submissionStatus: 'submitted', connection: 'online', lastSync: '21:36' }
    ]
  };

  function getRoundById(id) {
    return rounds.find(function (round) { return round.id === Number(id); }) || null;
  }

  function getRoundJudges(roundId) {
    return (judgesByRound[Number(roundId)] || []).slice();
  }

  window.KreenAdminData = {
    event: { name: 'King & Queen of the Pacific', year: '2026' },
    rounds: rounds,
    getRoundById: getRoundById,
    getRoundJudges: getRoundJudges,
  };
})();
