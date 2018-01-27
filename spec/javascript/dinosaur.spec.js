import Dinosaur from '../../app/javascript/packs/dinosaur'

test("Dinosaurs are extinct", () => {
  expect((new Dinosaur).isExtinct).toBeTruthy();
});
