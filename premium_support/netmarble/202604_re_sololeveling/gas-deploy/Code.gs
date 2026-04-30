function doGet() {
  return HtmlService.createHtmlOutputFromFile('index')
    .setTitle('260420_re_lat_ios_attribution_benchmark')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}
