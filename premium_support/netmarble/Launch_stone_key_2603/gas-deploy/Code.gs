function doGet() {
  return HtmlService.createHtmlOutputFromFile('index')
    .setTitle('StoneAge KOR Performance Diagnosis')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}
