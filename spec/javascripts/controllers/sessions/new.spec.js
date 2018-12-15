import Controller from '../../../../app/javascript/controllers/sessions/new_controller'
import { Application } from 'stimulus';

describe('sessions--new', () => {
  beforeEach(() => {
    fixture.setBase('spec/fixtures')
    const el = fixture.load('sessions-new.html')

    const application = new Application();
    application.router.start();
    application.dispatcher.start();
    application.register('sessions--new', Controller);
  });

  afterEach(() => {
    fixture.cleanup();
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
