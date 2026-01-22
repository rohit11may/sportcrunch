I don't want the method registry to be editable via the dashboard. The config files that are there should be so that they shouldn't actually be mapping to a form in the dashboard or be editable from the UI.  I want this to be easily selectable and rendered from within the dashboard and the swift implementations to be tied similarly to this structure. So for each method version, there should be a linked implementation in swift, ideally the same folder structure. I want the methods/ JSON to be defined in the app/ folder somewhere and for the dashboard/ to read it from this folder directly to serve the different options. The swift should also be reading the config json files to get the settings. If a method file doesn’t have a parallel swift implementation, there should be a build error on the app. I want it to be enforced that there are method jsons parallel to the swift.


methods/
├── spectral_flux/
│   ├── _family.json                    # Family-level metadata
│   │
│   ├── v1/
│   │   ├── method.json                 # Method definition for v1
│   │   └── configs/
│   │       └── default.config.json
│   │
│   ├── v2/
│   │   ├── method.json                 # Method definition for v2
│   │   └── configs/
│   │       ├── default.config.json
│   │       ├── aggressive.config.json
│   │       └── conservative.config.json
│   │
│   └── v3/
│       ├── method.json                 # Method definition for v3
│       └── configs/
│           ├── default.config.json
│           └── experimental.config.json
│
├── visual_scene_detect/
│   ├── _family.json
│   └── v1/
│       ├── method.json
│       └── configs/
│           └── default.config.json
│
└── _index.json                         # Auto-generated registry
