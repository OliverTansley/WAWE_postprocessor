# ICutWater Post Processor

## Installation

This post processor is designed for the ['icutWater Eco 2' waterjet.](https://emco.co.uk/icutwater-eco-series-water-jet-machine/), and can be installed directly into fusion360 by importing it into the [post library](https://www.autodesk.com/support/technical/article/caas/sfdcarticles/sfdcarticles/How-to-add-a-Post-Processor-to-your-Personal-Posts-in-Fusion-360.html).

## Usage

**POST OPERATES IN ABSOLUTE COORDINATES** This means once the cutting position is selected you **MUST** set this as the new home reference point which is found in kr8 drives menu labelled 'set 0 position' make sure this stays ticked.

The post processor offers two unique options for ensuring the correct gcode is generated depending on desired functionality and cutting material.

The three options are selected under post properties when using the post in fusion and are as follows:

- CutMaterial: determines what feed rate and abrasive flow rate to output dependant on material choice.
- Pause between profiles: when enabled will insert pause commands to wait for user input (ENTER key) between cut profiles to allow them to be removed.
- Separate word with space: when enabled will put spaces between codes and code arguments in the .CNC file (doesn't impact resulting cuts)

![](./PostProperties.png)

## Maintainance and modifications

### Executing nc output correctly

The nc output you wish to execute on the icutWater Eco 2 must conform to the following:

- file extension must be '.CNC'.
- file must pass the waterjets 'parsing' stage.

### nc output parsing

Before .cnc files can be executed on the icutWater Eco 2, the .cnc file is read in its entirety to test the formatting is as expected, the following rules are applied to the gcode beyond typical expectations of correctness:

- All arc commands must provide an X Y I and J argument even if the argument passed is 0.
- The following parameters must be set in this order: Feed rate (eg F321), abrasive flow rate (eg M200 1.5), acceleration (eg G131 10), kerf width (eg S0.9), and finally coordinate preference (either G90 or G91, this post uses G90)
- M02 must terminate the file as it is the 'end program' commands
- All G commands should be proceeded with two digits e.g. G01 G90 G03. Other than G0

Beyond these points traditional formatting constraints should be adhered to such as single instructions per line, comments prefixed with ';' etc.

## Code Organisation and descriptions
