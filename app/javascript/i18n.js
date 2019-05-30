import translations from 'i18n.json'; /* eslint-disable-line import/no-unresolved */

export default class {
  translate(key) {
    return this.constructor.translate(key);
  }

  static translate(key) {
    return translations[this.locale][key];
  }

  static get locale() {
    const html = document.querySelector('html');
    return html.getAttribute('lang') || 'en';
  }
}
