function doGet() {
  return HtmlService.createHtmlOutputFromFile('index')
    .setTitle('TSDS Origin Device Analysis')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}
