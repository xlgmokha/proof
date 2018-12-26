export default class {
  constructor(form) {
    this.form = form;
  }

  valid() {
    if (this.form.querySelectorAll('[data-input-valid="false"]').length > 0) return false;

    if (this.form.querySelectorAll('[data-checkbox-valid="false"]').length > 0) return false;

    return true;
  }
}
