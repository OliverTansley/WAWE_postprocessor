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

description = "Jet template (DEMO ONLY)";
vendor = "Autodesk";
vendorUrl = "http://www.autodesk.com";
legal = "Copyright (C) 2015-2021 by Autodesk, Inc.";
certificationLevel = 2;
minimumRevision = 45702;

longDescription = "This post demonstrates the capabilities of the post processor for waterjet, laser, and plasma cutting. You can use this as a foundation when you need a post for a new CNC. Note that this post cannot be used with milling toolpath. You can only use it for 'jet' style toolpath.";

extension = "nc";
setCodePage("ascii");

capabilities = CAPABILITY_JET;
tolerance = spatial(0.002, MM);

minimumChordLength = spatial(0.25, MM);
minimumCircularRadius = spatial(0.01, MM);
maximumCircularRadius = spatial(1000, MM);
minimumCircularSweep = toRad(0.01);
maximumCircularSweep = toRad(180);
allowHelicalMoves = false;
allowedCircularPlanes = undefined; // allow any circular motion

// user-defined properties
properties = {
  writeMachine: {
    title      : "Write machine",
    description: "Output the machine settings in the header of the code.",
    group      : "formats",
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  showSequenceNumbers: {
    title      : "Use sequence numbers",
    description: "Use sequence numbers for each block of outputted code.",
    group      : "formats",
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  sequenceNumberStart: {
    title      : "Start sequence number",
    description: "The number at which to start the sequence numbers.",
    group      : "formats",
    type       : "integer",
    value      : 10,
    scope      : "post"
  },
  sequenceNumberIncrement: {
    title      : "Sequence number increment",
    description: "The amount by which the sequence number is incremented by in each block.",
    group      : "formats",
    type       : "integer",
    value      : 5,
    scope      : "post"
  },
  allowHeadSwitches: {
    title      : "Allow head switches",
    description: "Enable to output code to allow heads to be manually switched for piercing and cutting.",
    group      : "preferences",
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  useRetracts: {
    title      : "Use retracts",
    description: "Output retracts, otherwise only output part contours for importing into a third-party jet application.",
    group      : "homePositions",
    type       : "boolean",
    value      : true,
    scope      : "post"
  },
  separateWordsWithSpace: {
    title      : "Separate words with space",
    description: "Adds spaces between words if 'yes' is selected.",
    group      : "formats",
    type       : "boolean",
    value      : true,
    scope      : "post"
  }
};

// wcs definiton
wcsDefinitions = {
  useZeroOffset: false,
  wcs          : [
    {name:"Standard", format:"#", range:[1, 1]}
  ]
};

var gFormat = createFormat({prefix:"G", decimals:0});
var mFormat = createFormat({prefix:"M", decimals:0});

var xyzFormat = createFormat({decimals:(unit == MM ? 3 : 4)});
var feedFormat = createFormat({decimals:(unit == MM ? 1 : 2)});
var secFormat = createFormat({decimals:3, forceDecimal:true}); // seconds - range 0.001-1000

var xOutput = createVariable({prefix:"X"}, xyzFormat);
var yOutput = createVariable({prefix:"Y"}, xyzFormat);
var feedOutput = createVariable({prefix:"F"}, feedFormat);

// circular output
var iOutput = createReferenceVariable({prefix:"I"}, xyzFormat);
var jOutput = createReferenceVariable({prefix:"J"}, xyzFormat);

var gMotionModal = createModal({}, gFormat); // modal group 1 // G0-G3, ...
var gAbsIncModal = createModal({}, gFormat); // modal group 3 // G90-91
var gUnitModal = createModal({}, gFormat); // modal group 6 // G20-21

// collected state
var sequenceNumber;
var currentWorkOffset;
var split = false;

/**
  Writes the specified block.
*/
function writeBlock() {
  if (getProperty("showSequenceNumbers")) {
    writeWords2("N" + sequenceNumber, arguments);
    sequenceNumber += getProperty("sequenceNumberIncrement");
  } else {
    writeWords(arguments);
  }
}

function formatComment(text) {
  return "(" + String(text).replace(/[()]/g, "") + ")";
}

/**
  Output a comment.
*/
function writeComment(text) {
  writeln(formatComment(text));
}

function onOpen() {

  if (!getProperty("separateWordsWithSpace")) {
    setWordSeparator("");
  }

  sequenceNumber = getProperty("sequenceNumberStart");

  if (programName) {
    writeComment(programName);
  }
  if (programComment) {
    writeComment(programComment);
  }

  // dump machine configuration
  var vendor = machineConfiguration.getVendor();
  var model = machineConfiguration.getModel();
  var description = machineConfiguration.getDescription();

  if (getProperty("writeMachine") && (vendor || model || description)) {
    writeComment(localize("Machine"));
    if (vendor) {
      writeComment("  " + localize("vendor") + ": " + vendor);
    }
    if (model) {
      writeComment("  " + localize("model") + ": " + model);
    }
    if (description) {
      writeComment("  " + localize("description") + ": "  + description);
    }
  }

  if (hasGlobalParameter("material")) {
    writeComment("MATERIAL = " + getGlobalParameter("material"));
  }

  if (hasGlobalParameter("material-hardness")) {
    writeComment("MATERIAL HARDNESS = " + getGlobalParameter("material-hardness"));
  }

  { // stock - workpiece
    var workpiece = getWorkpiece();
    var delta = Vector.diff(workpiece.upper, workpiece.lower);
    if (delta.isNonZero()) {
      writeComment("THICKNESS = " + xyzFormat.format(workpiece.upper.z - workpiece.lower.z));
    }
  }

  // absolute coordinates and feed per min
  writeBlock(gAbsIncModal.format(90));

  switch (unit) {
  case IN:
    writeBlock(gUnitModal.format(20));
    break;
  case MM:
    writeBlock(gUnitModal.format(21));
    break;
  }
}

function onComment(message) {
  writeComment(message);
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

function onSection() {
  var insertToolCall = isFirstSection() ||
    currentSection.getForceToolChange && currentSection.getForceToolChange() ||
    (tool.number != getPreviousSection().getTool().number);

  var retracted = false; // specifies that the tool has been retracted to the safe plane
  var newWorkOffset = isFirstSection() ||
    (getPreviousSection().workOffset != currentSection.workOffset); // work offset changes
  var newWorkPlane = isFirstSection() ||
    !isSameDirection(getPreviousSection().getGlobalFinalToolAxis(), currentSection.getGlobalInitialToolAxis());

  writeln("");

  if (hasParameter("operation-comment")) {
    var comment = getParameter("operation-comment");
    if (comment) {
      writeComment(comment);
    }
  }

  if (insertToolCall) {
    retracted = true;
    onCommand(COMMAND_COOLANT_OFF);

    switch (tool.type) {
    case TOOL_WATER_JET:
      writeComment("Waterjet cutting.");
      break;
    case TOOL_LASER_CUTTER:
      writeComment("Laser cutting");
      break;
    case TOOL_PLASMA_CUTTER:
      writeComment("Plasma cutting");
      break;
    /*
    case TOOL_MARKER:
      writeComment("Marker");
      break;
    */
    default:
      error(localize("The CNC does not support the required tool."));
      return;
    }
    writeln("");

    writeComment("tool.jetDiameter = " + xyzFormat.format(tool.jetDiameter));
    writeComment("tool.jetDistance = " + xyzFormat.format(tool.jetDistance));
    writeln("");

    switch (currentSection.jetMode) {
    case JET_MODE_THROUGH:
      writeComment("THROUGH CUTTING");
      break;
    case JET_MODE_ETCHING:
      writeComment("ETCH CUTTING");
      break;
    case JET_MODE_VAPORIZE:
      writeComment("VAPORIZE CUTTING");
      break;
    default:
      error(localize("Unsupported cutting mode."));
      return;
    }
    writeComment("QUALITY = " + currentSection.quality);

    if (tool.comment) {
      writeComment(tool.comment);
    }
    writeln("");
  }

  /*
  // wcs
  if (insertToolCall) { // force work offset when changing tool
    currentWorkOffset = undefined;
  }

  if (currentSection.workOffset != currentWorkOffset) {
    writeBlock(currentSection.wcs);
    currentWorkOffset = currentSection.workOffset;
  }
 */

  forceXYZ();

  { // pure 3D
    var remaining = currentSection.workPlane;
    if (!isSameDirection(remaining.forward, new Vector(0, 0, 1))) {
      error(localize("Tool orientation is not supported."));
      return;
    }
    setRotation(remaining);
  }

  /*
  // set coolant after we have positioned at Z
  if (false) {
    var c = mapCoolantTable.lookup(tool.coolant);
    if (c) {
      writeBlock(mFormat.format(c));
    } else {
      warning(localize("Coolant not supported."));
    }
  }
*/

  forceAny();

  split = false;
  if (getProperty("useRetracts")) {

    var initialPosition = getFramePosition(currentSection.getInitialPosition());

    if (insertToolCall || retracted) {
      gMotionModal.reset();

      if (!machineConfiguration.isHeadConfiguration()) {
        writeBlock(
          gAbsIncModal.format(90),
          gMotionModal.format(0), xOutput.format(initialPosition.x), yOutput.format(initialPosition.y)
        );
      } else {
        writeBlock(
          gAbsIncModal.format(90),
          gMotionModal.format(0),
          xOutput.format(initialPosition.x),
          yOutput.format(initialPosition.y)
        );
      }
    } else {
      writeBlock(
        gAbsIncModal.format(90),
        gMotionModal.format(0),
        xOutput.format(initialPosition.x),
        yOutput.format(initialPosition.y)
      );
    }
  } else {
    split = true;
  }
}

function onDwell(seconds) {
  if (seconds > 99999.999) {
    warning(localize("Dwelling time is out of range."));
  }
  seconds = clamp(0.001, seconds, 99999.999);
  writeBlock(gFormat.format(4), "X" + secFormat.format(seconds));
}

function onCycle() {
  onError("Drilling is not supported by CNC.");
}

var pendingRadiusCompensation = -1;

function onRadiusCompensation() {
  pendingRadiusCompensation = radiusCompensation;
}

var shapeArea = 0;
var shapePerimeter = 0;
var shapeSide = "inner";
var cuttingSequence = "";

function onParameter(name, value) {
  if ((name == "action") && (value == "pierce")) {
    writeComment("RUN POINT-PIERCE COMMAND HERE");
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

var deviceOn = false;

function setDeviceMode(enable) {
  if (enable != deviceOn) {
    deviceOn = enable;
    if (enable) {
      writeComment("TURN ON CUTTING HERE");
    } else {
      writeComment("TURN OFF CUTTING HERE");
    }
  }
}

function onPower(power) {
  setDeviceMode(power);
}

function onRapid(_x, _y, _z) {

  if (!getProperty("useRetracts") && ((movement == MOVEMENT_RAPID) || (movement == MOVEMENT_HIGH_FEED))) {
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
      error(localize("Radius compensation mode cannot be changed at rapid traversal."));
      return;
    }
    writeBlock(gMotionModal.format(0), x, y);
    feedOutput.reset();
  }
}

function onLinear(_x, _y, _z, feed) {

  if (!getProperty("useRetracts") && ((movement == MOVEMENT_RAPID) || (movement == MOVEMENT_HIGH_FEED))) {
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
    if (getNextRecord().isMotion()) { // try not to output feed without motion
      feedOutput.reset(); // force feed on next line
    } else {
      writeBlock(gMotionModal.format(1), f);
    }
  }
}

function onRapid5D(_x, _y, _z, _a, _b, _c) {
  error(localize("The CNC does not support 5-axis simultaneous toolpath."));
}

function onLinear5D(_x, _y, _z, _a, _b, _c, feed) {
  error(localize("The CNC does not support 5-axis simultaneous toolpath."));
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

  if (!getProperty("useRetracts") && ((movement == MOVEMENT_RAPID) || (movement == MOVEMENT_HIGH_FEED))) {
    doSplit();
    return;
  }

  // one of X/Y and I/J are required and likewise

  if (pendingRadiusCompensation >= 0) {
    error(localize("Radius compensation cannot be activated/deactivated for a circular move."));
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
      writeBlock(gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), feedOutput.format(feed));
      break;
    default:
      linearize(tolerance);
    }
  } else {
    switch (getCircularPlane()) {
    case PLANE_XY:
      writeBlock(gMotionModal.format(clockwise ? 2 : 3), xOutput.format(x), yOutput.format(y), iOutput.format(cx - start.x, 0), jOutput.format(cy - start.y, 0), feedOutput.format(feed));
      break;
    default:
      linearize(tolerance);
    }
  }
}

var mapCommand = {
  COMMAND_STOP         : 0,
  COMMAND_OPTIONAL_STOP: 1,
  COMMAND_END          : 2
};

function onCommand(command) {
  switch (command) {
  case COMMAND_POWER_ON:
    return;
  case COMMAND_POWER_OFF:
    return;
  case COMMAND_COOLANT_ON:
    return;
  case COMMAND_COOLANT_OFF:
    return;
  case COMMAND_LOCK_MULTI_AXIS:
    return;
  case COMMAND_UNLOCK_MULTI_AXIS:
    return;
  case COMMAND_BREAK_CONTROL:
    return;
  case COMMAND_TOOL_MEASURE:
    return;
  }

  var stringId = getCommandStringId(command);
  var mcode = mapCommand[stringId];
  if (mcode != undefined) {
    writeBlock(mFormat.format(mcode));
  } else {
    onUnsupportedCommand(command);
  }
}

function onSectionEnd() {
  setDeviceMode(false);
  forceAny();
}

function onClose() {
  writeln("");

  onCommand(COMMAND_COOLANT_OFF);

  onImpliedCommand(COMMAND_END);
  writeBlock(mFormat.format(30)); // stop program
}

function setProperty(property, value) {
  properties[property].current = value;
}
