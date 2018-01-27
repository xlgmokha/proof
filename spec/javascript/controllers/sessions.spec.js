import SessionController from '../../../app/javascript/packs/controllers/sessions_controller'

describe('SessionsController', () => {
  let subject = null;

  beforeEach(() => {
    subject = new SessionController();
  });

  it("is alive", () => {
    expect(subject).toBeInstanceOf(SessionController);
  });

  describe("validate", () => {
    xit("disables the submit button when the email is blank", () => {
      subject.validate();
    });
  });
});
