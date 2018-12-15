import validator from 'validator';
import ApplicationController from './application_controller';
import FormValidation from '../models/form_validation';
import I18n from '../i18n';

export default class extends ApplicationController {
  get form() { return this.element.closest('form'); }

  get formValidation() { return new FormValidation(this.form); }

  get submitButton() { return this.form.querySelector('[type=submit]'); }

  changed() {
    this.validate(this.element);

    if (this.formValidation.valid()) super.enable(this.submitButton);
  }

  validate(element) {
    const isRequired = element.getAttribute('required') === 'required';
    if (isRequired && element.value.length === 0) {
      return this.displayError(I18n.translate('js.form.errors.required'));
    }

    const isEmail = element.getAttribute('type') === 'email';
    if (isEmail && !validator.isEmail(element.value)) {
      return this.displayError(I18n.translate('js.form.errors.invalid'));
    }

    const minLength = element.getAttribute('minlength');
    if (minLength && element.value.length < parseInt(minLength, 10)) {
      return this.displayError(I18n.translate('js.form.errors.too_short'));
    }

    const maxLength = element.getAttribute('maxlength');
    if (maxLength && element.value.length > parseInt(maxLength, 10)) {
      return this.displayError(I18n.translate('js.form.errors.too_long'));
    }

    const isEqualTo = element.getAttribute('data-is-equal-to');
    if (isEqualTo && document.querySelector(isEqualTo).value !== element.value) {
      return this.displayError(I18n.translate('js.form.errors.confirmation'));
    }

    return this.hideError();
  }

  hideError() {
    this.data.set('valid', true);
    this.element.classList.remove('is-danger');
    const controlElement = this.element.parentElement;
    const fieldElement = controlElement.parentElement;
    const helpElement = fieldElement.querySelector('.help');
    if (helpElement) {
      helpElement.textContent = '';
      helpElement.classList.remove('is-danger');
      super.hide(helpElement);
    }
  }

  displayError(message) {
    this.data.set('valid', false);
    super.disable(this.submitButton);
    this.element.classList.add('is-danger');
    const controlElement = this.element.parentElement;
    const fieldElement = controlElement.parentElement;
    const helpElement = fieldElement.querySelector('.help');
    if (helpElement) {
      helpElement.textContent = message;
      helpElement.classList.add('is-danger');
      super.show(helpElement);
    }
  }
}
