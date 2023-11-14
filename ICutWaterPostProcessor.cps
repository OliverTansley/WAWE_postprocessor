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
extension = "CNC";
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
allowedCircularPlanes = undefined;

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
  overwriteFeedRate: {
    title: "Feed Rate",
    description: "How fast the cutting head moves",
    group: "Material",
    type: "string",
    value: "",
  },
  overwriteAbrasiveRate: {
    title: "Abrasive Rate",
    description: "How much abrasive is provided",
    group: "Material",
    type: "string",
    value: "",
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
    description: "Feature is work in progress Do not enable",
    group: "Operation",
    type: "boolean",
    value: false,
  },
  // provides file path to .csv
  dataSheetPath: {
    title: "DataSheet file path",
    description: "Provide the file path to the materials datasheet",
    group: "Operation",
    type: "String",
    value: "datasheet.csv",
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

// circular output
var iOutput = createReferenceVariable({ prefix: "I" }, xyzFormat);
var jOutput = createReferenceVariable({ prefix: "J" }, xyzFormat);

// collected state
var sequenceNumber;

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
var matFeed = "";
function onOpen() {
  if (!getProperty("separateWordsWithSpace")) {
    setWordSeparator("");
  }

  sequenceNumber = getProperty("sequenceNumberStart");

  switch (getProperty("cutMaterial")) {
    case "1": // alu 8mm goood
      matFeed = "70";
      abrFeed = "1.5";
      break;
    case "2": // alu 6mm rough
      matFeed = "188";
      abrFeed = "1.5";
      break;
    case "3": // alu 6mm medium
      matFeed = "150";
      abrFeed = "1.5";
      break;
    case "4": // alu 3mm medium
      matFeed = "321";
      abrFeed = "1.5";
      break;
    case "5": // alu 1mm medium
      matFeed = "1140";
      abrFeed = "1";
      break;
    case "6": // alu 1mm good
      matFeed = "760";
      abrFeed = "1";
      break;
    case "7": // alu 1mm fine
      matFeed = "290";
      abrFeed = "1.5";
      break;
    default:
      error("Unknown material provided");
  }
  if (getProperty("overwriteAbrasiveRate")) {
    writeBlock("M200", getProperty("overwriteAbrasiveRate"));
  } else {
    writeBlock("M200", abrFeed);
  }
  if (getProperty("overwriteFeedRate")) {
    writeBlock("F" + getProperty("overwriteFeedRate"));
  } else {
    writeBlock("F" + matFeed);
  }
  writeBlock("G131", "10"); //acceleration 10mm/s^2
  writeBlock("S0.9"); //kerf width
  writeBlock("G90");
  initCSV();
}

/** Force output of X, Y, and Z. */
function forceXYZ() {
  xOutput.reset();
  yOutput.reset();
}

/** Force output of X, Y, Z, A, B, C, and F on next output. */
function forceAny() {
  forceXYZ();
}

/**
  onSection runs between separate tool changes (not needed for this water-jet)
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
  writeBlock("G04", seconds);
}

var pendingRadiusCompensation = -1;
function onRadiusCompensation() {
  pendingRadiusCompensation = radiusCompensation;
}

var shapePerimeter = 0;
var shapeSide = "inner";
var cuttingSequence = "";
var shapeArea = 0;
/**
 Executes commands based on parameters passed by fusion
 */
function onParameter(name, value) {
  if (name == "action" && value == "pierce") {
    writeBlock("M1102");
    onDwell(2);
  } else if (name == "beginSequence") {
    if (value == "piercing") {
      cuttingSequence = value;
    }
  }
}

/**
 Toggles device from on and off
 */
var deviceOn = false;
function onPower(enable) {
  if (enable != deviceOn) {
    deviceOn = enable;
    if (enable) {
      writeBlock("M1100");
    } else {
      writeBlock("M1103");
      onDwell(2);
      writeBlock("M1101");
      if (getProperty("pauseDelimited")) {
        writeComment("INSERT PAUSE COMMAND HERE");
      }
    }
  }
}

/*
  Performs rapid movement G0 command
*/
function onRapid(_x, _y, _z) {
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
    writeBlock("G0", x, y);
  }
}

/**
  performs G1 linear movement command
 */
function onLinear(_x, _y, _z, feed) {
  // at least one axis is required
  if (pendingRadiusCompensation >= 0) {
    // ensure that we end at desired position when compensation is turned off
    xOutput.reset();
    yOutput.reset();
  }
  var x = xOutput.format(_x);
  var y = yOutput.format(_y);
  if (x || y) {
    if (pendingRadiusCompensation >= 0) {
      pendingRadiusCompensation = -1;
      switch (radiusCompensation) {
        case RADIUS_COMPENSATION_LEFT:
          writeBlock(gFormat.format(41));
          writeBlock("G01", x, y);
          break;
        case RADIUS_COMPENSATION_RIGHT:
          writeBlock(gFormat.format(42));
          writeBlock("G01", x, y);
          break;
        default:
          writeBlock(gFormat.format(40));
          writeBlock("G01", x, y);
      }
    } else {
      writeBlock("G01", x, y);
    }
  }
}

/**
 * performs G02 or G03 circular movement
 */
function onCircular(clockwise, cx, cy, cz, x, y, z, feed) {
  // one of X/Y and I/J are required and likewise

  if (pendingRadiusCompensation >= 0) {
    error(
      localize(
        "Radius compensation cannot be activated/deactivated for a circular move."
      )
    );
    return;
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
          clockwise ? "G02" : "G03",
          xOutput.format(x),
          iOutput.format(cx - start.x, 1),
          jOutput.format(cy - start.y, 1)
        );
        break;
      default:
        linearize(tolerance);
    }
  } else {
    switch (getCircularPlane()) {
      case PLANE_XY:
        writeBlock(
          clockwise ? "G02" : "G03",
          xOutput.format(x),
          yOutput.format(y),
          iOutput.format(cx - start.x, 1),
          jOutput.format(cy - start.y, 1)
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
  onPower(false);
  forceAny();
}

/**
 Terminate program
 */
function onClose() {
  writeBlock("M02"); // stop program
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

/**
 * CSV DATA SHEET
 */
// var headings = [];
// var materials = [];
// function initCSV() {
//   writeComment("hello");
//   const fs = require("fs");
//   const path = getProperty("dataSheetPath");

//   fs.createReadStream(path)
//     .pipe(parse({ delimiter: ",", from_line: 1 }))
//     .on("start", (row) => {
//       for (const heading in row) {
//         headings.push(heading);
//       }
//     })
//     .on("data", (row) => {
//       // executed for each row of data
//       materials.push(constructJson(headings, row));
//     })
//     .on("error", (error) => {
//       // Handle the errors
//       error(error.message);
//     });
//   writeComment(materials.length);
//   for (const mat in materials) {
//     writeComment(toString(mat));
//   }
// }

// function constructJson(headings, dataPoints) {
//   return headings.reduce((acc, heading, index) => {
//     acc[heading] = dataPoints[index];
//     return JSON.stringify(acc);
//   }, {});
// }
