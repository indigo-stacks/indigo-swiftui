import ProjectDescription
import ProjectDescriptionHelpers

let project = Project.framework(
  name: "NotesListFeature",
  dependencies: [
    .project(target: "Core", path: .relativeToRoot("Core")),
    .project(target: "NoteEditorFeature", path: .relativeToRoot("NoteEditorFeature"))
  ] + .indigoFoundation,
  testDependencies: [
    .project(target: "Core", path: .relativeToRoot("Core")),
    .project(target: "NoteEditorFeature", path: .relativeToRoot("NoteEditorFeature"))
  ] + .indigoFoundation
)
