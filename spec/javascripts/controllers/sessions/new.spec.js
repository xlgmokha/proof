import Controller from '../../../../app/javascript/controllers/sessions/new_controller'
import { Application } from 'stimulus';

describe('sessions--new', () => {
  beforeEach(() => {
    let $form = affix('form[data-controller="sessions--new"]')
    $form.affix('input[data-target="sessions--new.email" data-action="keyup->sessions--new#validate" type="email" id="user_email"]')
    $form.affix('input[data-target="sessions--new.password" data-action="keyup->sessions--new#validate" type="password" id="user_password"]')
    $form.affix('button[name="button" type="submit" data-target="sessions--new.submit"]')
    const application = new Application();
    application.router.start();
    application.dispatcher.start();
    application.register('sessions--new', Controller);
  });

  describe("validate", () => {
    let emailField;
    let passwordField;

    beforeEach(() => {
      emailField = document.getElementById('user_email')
      passwordField = document.getElementById('user_password')
    });

    it("disables the submit button when the email is blank", () => {
      emailField.value = ''
      emailField.dispatchEvent(new Event('keyup'))
      expect($('button[type="submit"]').attr('disabled')).toBe('disabled')
    });

    it("disables the submit button when the password is blank", () => {
      passwordField.value = ''
      passwordField.dispatchEvent(new Event('keyup'))
      expect($('button[type="submit"]').attr('disabled')).toBe('disabled')
    });

    it ("enables the submit button when all fields are provided", () => {
      emailField.value = 'email@example.com';
      emailField.dispatchEvent(new Event('keyup'))
      passwordField.value = 'password';
      passwordField.dispatchEvent(new Event('keyup'))
      expect($('button[type="submit"]').attr('disabled')).toBe(undefined)
    });
  });
});
