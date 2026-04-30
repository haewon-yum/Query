/**
 * ODSB-17593 · KB Securities investigation report — Drive-backed web-app router.
 *
 * Routes:
 *   (no param)       → EN (default)
 *   ?lang=en         → EN
 *   ?lang=ko         → KO
 *
 * Content is loaded live from Google Drive on each request. To update the
 * report, simply replace the file contents in Drive (via Apps Script's "Manage
 * versions" on the file, or overwrite via re-upload) — no redeploy needed.
 *
 * Permissions required (auto-prompted on first deploy):
 *   - https://www.googleapis.com/auth/drive.readonly
 *
 * Deploy: Deploy → New deployment → Web app
 *   Execute as     : Me
 *   Who has access : Anyone within Moloco (recommended) or Anyone with the link
 */

// >>> CONFIRM these mappings before first deploy. Swap if EN/KO are reversed. <<<
var FILE_IDS = {
  en: '128pd5zS9K7OOSNZcpICpIfJj62UqjVkX',  // EN: investigation_57f49cb_REPORT_v2_deploy_en.html
  ko: '1yVIdoqmlVNx4q5kguL-ect3kcO0xWF-R'   // KO: investigation_57f49cb_REPORT_v2_deploy_ko.html
};

function doGet(e) {
  var lang = ((e && e.parameter && e.parameter.lang) || 'en').toLowerCase();
  if (lang !== 'en' && lang !== 'ko') lang = 'en';

  var fileId = FILE_IDS[lang];
  var html;
  try {
    html = DriveApp.getFileById(fileId).getBlob().getDataAsString('UTF-8');
  } catch (err) {
    return HtmlService.createHtmlOutput(
      '<h2>Failed to load report</h2>' +
      '<p>Lang: <code>' + lang + '</code>, File ID: <code>' + fileId + '</code></p>' +
      '<p>Error: <code>' + err.message + '</code></p>' +
      '<p>Check that the file exists, is accessible to this Apps Script project, and that the Drive API is authorized.</p>'
    );
  }

  // Apps Script serves HTML in an inner iframe (googleusercontent.com).
  // Relative hrefs like "?lang=ko" resolve against the INNER frame's URL,
  // so even with target="_top" the browser would navigate the parent to a
  // blank googleusercontent URL. Rewrite to an absolute Apps Script exec URL.
  var baseUrl = ScriptApp.getService().getUrl();  // .../exec
  html = html.replace(
    /<a href="\?lang=(en|ko)"/g,
    '<a target="_top" rel="noopener" href="' + baseUrl + '?lang=$1"'
  );

  var title = (lang === 'ko')
    ? 'ODSB-17593 · KB증권 iOS 인스톨 하락 조사 v2'
    : 'ODSB-17593 · KB Securities iOS Install Drop Investigation v2';

  return HtmlService
    .createHtmlOutput(html)
    .setTitle(title)
    .setXFrameOptionsMode(HtmlService.XFrameOptionsMode.ALLOWALL);
}

/**
 * Optional — run this from the Apps Script editor once to pre-authorize
 * Drive access before the first web-app deploy, so the consent screen doesn't
 * surprise end-users on first page load.
 */
function authorizeDriveAccess() {
  var en = DriveApp.getFileById(FILE_IDS.en);
  var ko = DriveApp.getFileById(FILE_IDS.ko);
  Logger.log('EN: ' + en.getName() + ' (' + en.getId() + ')');
  Logger.log('KO: ' + ko.getName() + ' (' + ko.getId() + ')');
}
