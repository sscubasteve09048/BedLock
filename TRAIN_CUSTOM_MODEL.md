# Training a custom "is my bed made" model

This trains a small image classifier on photos of *your specific bed* —
which is a much easier problem than general "what does a bed look like"
(that's why the built-in `VisionBedVerificationService` heuristic struggles).
A model that only ever has to recognize one room, in roughly the same
lighting and camera angle, from a few dozen of your own photos, can get very
accurate very quickly.

Two paths depending on whether you have Mac access:

- **Path A (has a Mac, even briefly):** Apple's **Create ML** app — free, no
  code, drag-and-drop.
- **Path B (no Mac at all):** a free Google Colab notebook that trains the
  same kind of model in Python and exports it to the exact format BedLock
  expects. This is the path if you're fully on the free/no-Mac setup from
  the rest of this project.

Either way, the output is a file called `BedMadeClassifier.mlpackage`. The
easiest path from there is importing it directly on your phone in
**Settings → Import Custom Model** — no rebuild, no reinstall, no computer
even required for that step. `CoreMLBedVerificationService.swift` already
knows to look for it and use it automatically over the built-in heuristic.

## Step 1: Collect photos

Take photos of **your own bed**, from **roughly the same spot** each time
(e.g. standing in the doorway) since the model only needs to solve this one
scene, not beds in general:

- **~40-80 photos of your bed made** — vary the time of day/lighting, slight
  angle changes, whether the door/curtains are open, different pillow
  arrangements you'd still call "made," etc. More variety here = more robust.
- **~40-80 photos of your bed unmade** — similarly varied: sheets pulled
  back, pillows scattered, blanket bunched, mid-morning vs. just-woken-up
  mess, etc.

More photos help, but for a single fixed scene like this, even 25-30 per
class can produce a usable model — you can always retrain with more later.
Use your phone's regular Camera app; no special equipment needed. AirDrop or
upload them to your computer afterward, sorted into two folders:

```
bed_photos/
  made/       (all your "made" photos)
  not_made/   (all your "unmade" photos)
```

**Use exactly these two folder/class names — `made` and `not_made`** — not
`unmade`. `CoreMLBedVerificationService.swift` checks for the exact string
`"made"`, and `"unmade"` would actually match too (it contains the substring
"made"), which would silently misclassify everything. `not_made` avoids the
ambiguity entirely.

## Path A: Create ML (if you have Mac access)

1. Open **Create ML** (Applications → Xcode → Open Developer Tool → Create
   ML, or search Spotlight for "Create ML" if you have Xcode installed).
2. New Document → **Image Classifier**.
3. Drag your `bed_photos` folder (with the `made`/`not_made` subfolders) into
   the Training Data well — Create ML auto-detects the class folders.
4. Optionally add a separate small Testing Data set (a few photos per class
   not used in training) to see real accuracy numbers.
5. Click **Train** (takes a few minutes on a Mac).
6. Once done, go to the **Output** tab and click **Get** → save as
   `BedMadeClassifier.mlpackage`.
7. Skip to **Step 3: Add the model to the Xcode project** below.

## Path B: Google Colab (no Mac needed)

1. Go to **colab.research.google.com** → New Notebook. It's free, runs in
   your browser, no installation.
2. Zip your `bed_photos` folder on your computer and upload it into the
   Colab session (the folder icon on the left sidebar → upload), or upload it
   to Google Drive and mount your Drive from the notebook — either works.
3. Paste the script below into a cell and run it (Colab already has
   TensorFlow installed; it'll install `coremltools` itself).

```python
# --- Cell 1: install coremltools (TensorFlow is preinstalled in Colab) ---
!pip install -q coremltools

# --- Cell 2: unzip your uploaded photos (skip if you used Drive instead) ---
!unzip -q bed_photos.zip -d /content/

# --- Cell 3: train a small transfer-learning classifier on your photos ---
import tensorflow as tf
import coremltools as ct

DATA_DIR = "/content/bed_photos"   # must contain made/ and not_made/ subfolders
IMG_SIZE = (224, 224)
BATCH_SIZE = 8

train_ds = tf.keras.utils.image_dataset_from_directory(
    DATA_DIR, validation_split=0.2, subset="training", seed=42,
    image_size=IMG_SIZE, batch_size=BATCH_SIZE, label_mode="categorical",
)
val_ds = tf.keras.utils.image_dataset_from_directory(
    DATA_DIR, validation_split=0.2, subset="validation", seed=42,
    image_size=IMG_SIZE, batch_size=BATCH_SIZE, label_mode="categorical",
)

# IMPORTANT: this must print ['made', 'not_made'] (alphabetical) — Colab
# infers class names from your folder names, so double check them here.
class_names = train_ds.class_names
print("Classes:", class_names)

# Light augmentation since we only have a few dozen photos per class.
augmentation = tf.keras.Sequential([
    tf.keras.layers.RandomFlip("horizontal"),
    tf.keras.layers.RandomRotation(0.05),
    tf.keras.layers.RandomZoom(0.1),
    tf.keras.layers.RandomBrightness(0.15),
])

base_model = tf.keras.applications.MobileNetV2(
    input_shape=IMG_SIZE + (3,), include_top=False, weights="imagenet"
)
base_model.trainable = False  # freeze — we're fine-tuning just the head

inputs = tf.keras.Input(shape=IMG_SIZE + (3,))
x = augmentation(inputs)
x = tf.keras.applications.mobilenet_v2.preprocess_input(x)
x = base_model(x, training=False)
x = tf.keras.layers.GlobalAveragePooling2D()(x)
x = tf.keras.layers.Dropout(0.3)(x)
outputs = tf.keras.layers.Dense(len(class_names), activation="softmax")(x)
model = tf.keras.Model(inputs, outputs)

model.compile(optimizer="adam", loss="categorical_crossentropy", metrics=["accuracy"])
model.fit(train_ds, validation_data=val_ds, epochs=15)

# --- Cell 4: convert to Core ML and download ---
mlmodel = ct.convert(
    model,
    inputs=[ct.ImageType(shape=(1,) + IMG_SIZE + (3,), scale=1/127.5, bias=[-1, -1, -1])],
    classifier_config=ct.ClassifierConfig(class_labels=class_names),
    minimum_deployment_target=ct.target.iOS16,
)
mlmodel.save("BedMadeClassifier.mlpackage")

from google.colab import files
import shutil
shutil.make_archive("BedMadeClassifier_mlpackage", "zip", "BedMadeClassifier.mlpackage")
files.download("BedMadeClassifier_mlpackage.zip")
```

4. This downloads `BedMadeClassifier_mlpackage.zip`. Unzip it on your
   computer — you'll get a `BedMadeClassifier.mlpackage` **folder** (Core ML
   packages are folders, not single files; keep its internal structure
   intact).
5. Sanity check the printed `Classes:` line from Cell 3 — it must read
   `['made', 'not_made']`. If it's reversed or different, your folder names
   don't match; fix them and rerun.

## Step 3: Get the model onto your phone

There are two ways to do this — pick based on whether you want the model to
survive an app reinstall (rare) or just want the fastest way to iterate:

### Option A: Import it in-app (recommended — no rebuild, no reinstall)

Once BedLock is installed (however you did that the first time — Sideloadly,
TestFlight, Xcode, whatever), you never need to touch the build pipeline
again just to update the model:

1. Get `BedMadeClassifier.mlpackage` onto your **phone itself**. Easiest ways:
   - If you trained via Colab on your phone's browser, just tap the download
     link — it lands in the Files app under Downloads.
   - If you trained on a computer, AirDrop the `.mlpackage` to your phone, or
     upload it to iCloud Drive/Google Drive and open it in Files on your phone.
2. Open **BedLock → Settings → Import Custom Model**.
3. Pick the `.mlpackage` from the file browser that appears.
4. That's it — the model compiles and takes effect immediately. No rebuild,
   no reinstall, no waiting on GitHub Actions.

This is also exactly how you retrain going forward: recollect a few photos
whenever accuracy drifts (lighting changes, moved furniture, etc.), rerun the
Colab script, and re-import the new `.mlpackage` the same way. If a retrain
ever makes things worse, tap **Remove Imported Model** in Settings to
instantly fall back to whatever was there before — no rebuild needed for
that either.

### Option B: Bake it into the app bundle (only if you want it to survive a full reinstall)

An imported model (Option A) lives in the app's Application Support
directory, which is deleted if you ever delete and reinstall the app from
scratch. If you'd rather have the model ship as part of the app build itself
(so a fresh install already has it), add it to the Xcode project instead —
this does require rebuilding and reinstalling the app afterward:

```bash
python3 scripts/add_ml_model_to_xcodeproj.py BedMadeClassifier.mlpackage
git add -A
git commit -m "Add custom-trained bed classifier model"
git push
```

Then re-run your GitHub Actions build (or open in Xcode if you have Mac
access) and reinstall. `CoreMLBedVerificationService` checks for an imported
model first and only falls back to this bundled copy if nothing's been
imported — so Option A always takes priority if you use both.

Either way, `BedVerificationService` already prefers whichever custom model
is present over the built-in heuristic automatically — no other code changes
needed. If no model is present at all, it falls back to
`VisionBedVerificationService` as before.

## Retraining later

Made a mistake in your dataset, or want to add more photos after seeing how
the model does in real use? Just repeat Steps 1-2 with the updated photo set,
then re-import via **Settings → Import Custom Model** (Option A above) — no
rebuild needed. The Settings screen also has a **Remind Me to Retrain**
toggle that nudges you periodically, since lighting and bedding changes over
time can quietly degrade an old model.
