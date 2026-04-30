function doGet() {
  return HtmlService.createHtmlOutputFromFile('index')
    .setTitle('260420_cpi_install_to_login_analysis')
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}
