test('lists categories on home page', function() {
  var actual = $("#linksf li").text().replace(/\s+/g, ' ').trim().split(' '),
      expected = [
        'Shelter',
        'Food',
        'Medical',
        'Hygiene',
        'Technology',
        'Community'
      ];

  deepEqual(actual, expected);
});
