function doGet() {
  return HtmlService.createHtmlOutputFromFile('index')
    .setTitle('7DS Origin — RE Opportunity Analysis')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}
