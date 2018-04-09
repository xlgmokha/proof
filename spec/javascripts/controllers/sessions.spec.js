import SessionsController from '../../../app/javascript/controllers/sessions_controller'
import { Application } from 'stimulus';

describe('SessionsController', () => {
  beforeEach(() => {
    let $form = affix('form[data-controller="sessions"]')
    $form.affix('input[data-target="sessions.email" data-action="keyup->sessions#validate" type="email" id="user_email"]')
    $form.affix('input[data-target="sessions.password" data-action="keyup->sessions#validate" type="password" id="user_password"]')
    $form.affix('button[name="button" type="submit" data-target="sessions.submit"]')
    const application = Application.start();
    application.register('sessions', SessionsController);
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
