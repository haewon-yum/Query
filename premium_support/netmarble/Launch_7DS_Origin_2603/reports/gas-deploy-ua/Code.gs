function doGet() {
  return HtmlService.createHtmlOutputFromFile('index')
    .setTitle('7DS Origin — UA Retention & LTV Analysis')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}
