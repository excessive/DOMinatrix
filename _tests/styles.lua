local red = { 255, 0, 0, 255 }

return {
    { "element", {
        width  = 50,
        height = 50,
    }},

    { "element#four.red", {
        width  = 400,
        height = 200,
    }},

    { "element.root", {
        display = "block",
        width   = 300,
        height  = 200,
    }},

    { ".root", {
        { ".red", {
            display = "inline",
        }},

        width  = 400,
        height = 200,
    }},

    { ".root.red", {
        width  = 200,
        height = 200,
    }},

    { ".red", {
        text_color = red,
    }},

    { "element#four", {
        display = "inline",
        width   = 600,
        height  = 600,
    }},

    { ".red:last", {
        width  = 10,
        height = 10,
    }},
}
