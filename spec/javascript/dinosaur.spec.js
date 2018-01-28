import Dinosaur from '../../app/javascript/packs/dinosaur'

describe("Dinosaur", () => {
  it("Dinosaurs are extinct", () => {
    expect((new Dinosaur).isExtinct).toBeTruthy();
  });
});
