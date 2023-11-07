/**
  Copyright (C) 2015-2021 by Autodesk, Inc.
  All rights reserved.

  Jet template post processor configuration. This post is intended to show
  the capabilities for use with waterjet, laser, and plasma cutters. It only
  serves as a template for customization for an actual CNC.

  $Revision: 43759 a148639d401c1626f2873b948fb6d996d3bc60aa $
  $Date: 2022-04-12 21:31:49 $

  FORKID {51C1E5C7-D09E-458F-AC35-4A2CE1E0AE32}
*/

/* POST SETTINGS */
description = "i-cut waterjet";
vendor = "OliverTansley";
vendorUrl = "";
legal = "";
certificationLevel = 2;
minimumRevision = 45702;
longDescription = "New post processor for the IcutWater waterjet";
extension = "nc";
setCodePage("ascii");
capabilities = CAPABILITY_JET;
tolerance = spatial(0.002, MM);

// Built in preferences (Don't delete)
minimumChordLength = spatial(0.25, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(180);
allowHelicalMoves = false;
allowedCircularPlanes = undefined; // allow any circular motion

// User defined properties
properties = {
  // material enum is used to determine which cut speed and abrasive feed rate are used
  cutMaterial: {
    title: "CutMaterial",
    description: "What material will the post process cut for",
    group: "Material",
    type: "enum",
    value: "1",
    values: [
      { title: "Aluminium 8mm Good", id: "1" },
      { title: "Aluminium 6mm Rough", id: "2" },
      { title: "Aluminium 6mm Medium", id: "3" },
      { title: "Aluminium 3mm Medium", id: "4" },
      { title: "Aluminium 1mm Medium", id: "5" },
      { title: "Aluminium 1mm Good", id: "6" },
      { title: "Aluminium 1mm Fine", id: "7" },
    ],
  },
  // separateWordsWithSpace determines wether white space is put between codes and arguments on the same line
  separateWordsWithSpace: {
    title: "Separate word with space",
    description:
      "Indicates wether spaces are inserted between words and arguments",
    group: "formatting",
    type: "boolean",
    value: true,
  },
  // pauseDelimited determines wether the cutter should pause between profiles to allow for easy removal
  pauseDelimited: {
    title: "Pause between profiles",
    description:
      "If true the cutter will wait between profiles to allow safe removal of parts, press enter to move onto the next profile",
    group: "Operation",
    type: "boolean",
    value: false,
  },
};

// work coordinate system definition
wcsDefinitions = {
  useZeroOffset: false,
  wcs: [{ name: "Standard", format: "#", range: [1, 1] }],
};

// gcode and mcode formats
var gFormat = createFormat({ prefix: "G", decimals: 0 });
var mFormat = createFormat({ prefix: "M", decimals: 0 });

// data formats (coordinate,feed,time)
var xyzFormat = createFormat({ decimals: unit == MM ? 3 : 4 });
var feedFormat = createFormat({ decimals: unit == MM ? 1 : 2 });
var secFormat = createFormat({ decimals: 3, forceDecimal: true }); // seconds - range 0.001-1000

var xOutput = createVariable({ prefix: "X" }, xyzFormat);
var yOutput = createVariable({ prefix: "Y" }, xyzFormat);
var feedOutput = createVariable({ prefix: "F" }, feedFormat);

// circular output
var iOutput = createReferenceVariable({ prefix: "I" }, xyzFormat);
var jOutput = createReferenceVariable({ prefix: "J" }, xyzFormat);

var gMotionModal = createModal({}, gFormat); // modal group 1 // G0-G3, ...
var gAbsIncModal = createModal({}, gFormat); // modal group 3 // G90-91
var gUnitModal = createModal({}, gFormat); // modal group 6 // G20-21

// collected state
var sequenceNumber;
var split = false;

/**
  Writes code block of arguments passed
*/
function writeBlock() {
  if (getProperty("showSequenceNumbers")) {
    writeWords2("N" + sequenceNumber, arguments);
    sequenceNumber += getProperty("sequenceNumberIncrement");
  } else {
    writeWords(arguments);
  }
}

/**
  Writes a comment line
*/
function writeComment(text) {
  writeln("(" + String(text).replace(/[()]/g, "") + ")");
}

/**
  sets word separation, units, and feed-rate , and cutting speed based on material selected
 */
function onOpen() {
  if (!getProperty("separateWordsWithSpace")) {
    setWordSeparator("");
  }

  sequenceNumber = getProperty("sequenceNumberStart");

  writeComment(
    "MATERIAL = " +
      properties.cutMaterial.values[getProperty("cutMaterial") - 1].title
  );
  switch (getProperty("cutMaterial")) {
    case "1": // alu 8mm goood
      writeBlock("F70");
      writeBlock("M200", "1.5");
      break;
    case "2": // alu 6mm rough
      writeBlock("F188");
      writeBlock("M200", "1.5");
      break;
    case "3": // alu 6mm medium
      writeBlock("F150");
      writeBlock("M200", "1.5");
      break;
    case "4": // alu 3mm medium
      writeBlock("F321");
      writeBlock("M200", "1.5");
      break;
    case "5": // alu 1mm medium
      writeBlock("F1140");
      writeBlock("M200", "1");
      break;
    case "6": // alu 1mm good
      writeBlock("F760");
      writeBlock("M200", "1");
      break;
    case "7": // alu 1mm fine
      writeBlock("F290");
      writeBlock("M200", "1.5");
      break;
    default:
      error("Unknown material provided");
  }

  writeBlock("G131", "10"); //acceleration 10mm/s^2

  writeBlock(gAbsIncModal.format(90), "; absolute coordinates");

  switch (unit) {
    case IN:
      writeBlock(gUnitModal.format(20), "; units inches");
      break;
    case MM:
      writeBlock(gUnitModal.format(21), "; units millimeters");
      break;
  }
}

/** Force output of X, Y, and Z. */
function forceXYZ() {
  xOutput.reset();
  yOutput.reset();
}

/** Force output of X, Y, Z, A, B, C, and F on next output. */
function forceAny() {
  forceXYZ();
  feedOutput.reset();
}

/**
 Optionally adds a pause between all cutting profiles
 */
function onSection() {}

/**
 * Outputs dwell statement
 */
function onDwell(seconds) {
  if (seconds > 99999.999) {
    warning(localize("Dwelling time is out of range."));
  }
  seconds = clamp(0.001, seconds, 99999.999);
  writeBlock(
    gFormat.format(4),
    "X" + secFormat.format(seconds),
    "; dwell for piercing"
  );
  writeComment("Movement commands");
}

var pendingRadiusCompensation = -1;
function onRadiusCompensation() {
  pendingRadiusCompensation = radiusCompensation;
}

var shapePerimeter = 0;
var shapeSide = "inner";
var cuttingSequence = "";
var shapeArea = 0;
function onParameter(name, value) {
  if (name == "action" && value == "pierce") {
    onDwell(2);
  } else if (name == "shapeArea") {
    shapeArea = value;
    writeComment("SHAPE AREA = " + xyzFormat.format(shapeArea));
  } else if (name == "shapePerimeter") {
    shapePerimeter = value;
    writeComment("SHAPE PERIMETER = " + xyzFormat.format(shapePerimeter));
  } else if (name == "shapeSide") {
    shapeSide = value;
    writeComment("SHAPE SIDE = " + value);
  } else if (name == "beginSequence") {
    if (value == "piercing") {
      if (cuttingSequence != "piercing") {
        if (getProperty("allowHeadSwitches")) {
          writeln("");
          writeComment("Switch to piercing head before continuing");
          onCommand(COMMAND_STOP);
          writeln("");
        }
      }
    } else if (value == "cutting") {
      if (cuttingSequence == "piercing") {
        if (getProperty("allowHeadSwitches")) {
          writeln("");
          writeComment("Switch to cutting head before continuing");
          onCommand(COMMAND_STOP);
          writeln("");
        }
      }
    }
    cuttingSequence = value;
  }
}

function onPower(power) {
  setDeviceMode(power);
}

var deviceOn = false;
/**
 Toggles device from on and off
 */
function setDeviceMode(enable) {
  if (enable != deviceOn) {
    deviceOn = enable;
    if (enable) {
      writeln("");
      writeBlock("M1100", "; Start cutting");
      writeBlock("M1102");
    } else {
      writeBlock("M1103");
      writeBlock("M1101", " ; Stop cutting");
      if (getProperty("pauseDelimited")) {
        writeBlock(mFormat.format(999), "; PRESS ENTER TO CONTINUE");
      }
    }
  }
}

/*
  Performs rapid movement G0 command
*/
function onRapid(_x, _y, _z) {
  if (
    !getProperty("useRetracts") &&
    (movement == MOVEMENT_RAPID || movement == MOVEMENT_HIGH_FEED)
  ) {
    doSplit();
    return;
  }

  if (split) {
    split = false;
    var start = getCurrentPosition();
    onExpandedRapid(start.x, start.y, start.z);
  }

  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  if (x || y) {
    if (pendingRadiusCompensation >= 0) {
      error(
        localize(
          "Radius compensation mode cannot be changed at rapid traversal."
        )
      );
      return;
    }
    writeBlock(gMotionModal.format(0), x, y);
    feedOutput.reset();
  }
}

function onLinear(_x, _y, _z, feed) {
  if (
    !getProperty("useRetracts") &&
    (movement == MOVEMENT_RAPID || movement == MOVEMENT_HIGH_FEED)
  ) {
    doSplit();
    return;
  }

  if (split) {
    resumeFromSplit(feed);
  }

  // at least one axis is required
  if (pendingRadiusCompensation >= 0) {
    // ensure that we end at desired position when compensation is turned off
    xOutput.reset();
    yOutput.reset();
  }
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  var f = feedOutput.format(feed);
  if (x || y) {
    if (pendingRadiusCompensation >= 0) {
      pendingRadiusCompensation = -1;
      switch (radiusCompensation) {
        case RADIUS_COMPENSATION_LEFT:
          writeBlock(gFormat.format(41));
          writeBlock(gMotionModal.format(1), x, y, f);
          break;
        case RADIUS_COMPENSATION_RIGHT:
          writeBlock(gFormat.format(42));
          writeBlock(gMotionModal.format(1), x, y, f);
          break;
        default:
          writeBlock(gFormat.format(40));
          writeBlock(gMotionModal.format(1), x, y, f);
      }
    } else {
      writeBlock(gMotionModal.format(1), x, y, f);
    }
  } else if (f) {
    if (getNextRecord().isMotion()) {
      // try not to output feed without motion
      feedOutput.reset(); // force feed on next line
    } else {
      writeBlock(gMotionModal.format(1), f);
    }
  }
}

function doSplit() {
  if (!split) {
    split = true;
    gMotionModal.reset();
    xOutput.reset();
    yOutput.reset();
    feedOutput.reset();
  }
}

function resumeFromSplit(feed) {
  if (split) {
    split = false;
    var start = getCurrentPosition();
    var _pendingRadiusCompensation = pendingRadiusCompensation;
    pendingRadiusCompensation = -1;
    onExpandedLinear(start.x, start.y, start.z, feed);
    pendingRadiusCompensation = _pendingRadiusCompensation;
  }
}

function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  if (
    !getProperty("useRetracts") &&
    (movement == MOVEMENT_RAPID || movement == MOVEMENT_HIGH_FEED)
  ) {
    doSplit();
    return;
  }

  // one of X/Y and I/J are required and likewise

  if (pendingRadiusCompensation >= 0) {
    error(
      localize(
        "Radius compensation cannot be activated/deactivated for a circular move."
      )
    );
    return;
  }

  if (split) {
    resumeFromSplit(feed);
  }

  var start = getCurrentPosition();
  if (isFullCircle()) {
    if (isHelical()) {
      linearize(tolerance);
      return;
    }
    switch (getCircularPlane()) {
      case PLANE_XY:
        writeBlock(
          gMotionModal.format(clockwise ? 2 : 3),
          xOutput.format(x),
          iOutput.format(cx - start.x, 0),
          jOutput.format(cy - start.y, 0),
          feedOutput.format(feed)
        );
        break;
      default:
        linearize(tolerance);
    }
  } else {
    switch (getCircularPlane()) {
      case PLANE_XY:
        writeBlock(
          gMotionModal.format(clockwise ? 2 : 3),
          xOutput.format(x),
          yOutput.format(y),
          iOutput.format(cx - start.x, 0),
          jOutput.format(cy - start.y, 0),
          feedOutput.format(feed)
        );
        break;
      default:
        linearize(tolerance);
    }
  }
}

/**
 Writes applicable mcode for a command
 */
function onCommand(command) {
  var mapCommand = {
    COMMAND_STOP: 0,
    COMMAND_OPTIONAL_STOP: 1,
    COMMAND_END: 2,
  };
  var stringId = getCommandStringId(command);
  if (mapCommand[stringId] != undefined) {
    writeBlock(mFormat.format(mapCommand[stringId]));
  }
}

/**
 Turn off device at the end of each section
 */
function onSectionEnd() {
  setDeviceMode(false);
  forceAny();
}

/**
 Terminate program
 */
function onClose() {
  writeln("");

  onCommand(COMMAND_COOLANT_OFF);

  onImpliedCommand(COMMAND_END);
  writeBlock(gFormat.format(40)); // stop program
}

/**
 * UNSUPPORTED FUNCTIONALITY NOT REQUIRED BY WATER JETS
 */

function onRapid5D(_x, _y, _z, _a, _b, _c) {
  error(localize("The CNC does not support 5-axis simultaneous toolpath."));
}

function onLinear5D(_x, _y, _z, _a, _b, _c, feed) {
  error(localize("The CNC does not support 5-axis simultaneous toolpath."));
}
