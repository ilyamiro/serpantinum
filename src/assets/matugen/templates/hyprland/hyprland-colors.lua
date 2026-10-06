return {
    image = "{{image}}",
<* for name, value in colors *>
    {{name}} = "0xff{{value.default.hex_stripped}}",
<* endfor *>
}