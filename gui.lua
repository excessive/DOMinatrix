local path     = (...):gsub('%.[^%.]+$', '') .. "."
local Display  = require(path.."properties.display")
local elements = {}
local GUI      = {}

-- https://github.com/stevedonovan/Penlight/blob/master/lua/pl/path.lua#L286
local function format_path(path)
	local np_gen1, np_gen2 = '[^SEP]+SEP%.%.SEP?', 'SEP+%.?SEP'
	local np_pat1, np_pat2 = np_gen1:gsub('SEP', '/'), np_gen2:gsub('SEP', '/')
	local k

	repeat -- /./ -> /
		path, k = path:gsub(np_pat2, '/')
	until k == 0

	repeat -- A/../ -> (empty)
		path, k = path:gsub(np_pat1, '')
	until k == 0

	if path == '' then path = '.' end

	return path
end

function GUI:init(path)
	-- Load the default element classes
	local new_path      = path:gsub("%.", "/") .. "elements/"
	local element_files = love.filesystem.getDirectoryItems(new_path)

	for _, file in ipairs(element_files) do
		local name = file:sub(1, -5)
		elements[name] = love.filesystem.load(new_path .. file)(path)
	end

	self.draw_order    = {}
	self.elements      = {}
	self.styles        = {}
	self.key_down      = {}
	self.joystick_down = {}
	self.gamepad_down  = {}
	self.mouse_down    = {}
	self.active        = false
	self.hover         = false
	self.mx, self.my   = love.mouse.getPosition()
end

function GUI:update(dt)
	local hover  = false
	local mx, my = love.mouse.getPosition()

	local function check_binding(elements)
		for _, element in ipairs(elements) do
			if element:is_binding(mx, my) then
				hover = element
				check_binding(element.children)

				break
			end
		end
	end

	local i = #self.draw_order
	while i >= 1 do
		local element = self.draw_order[i]
		check_binding({ element })

		i = i - 1
		if hover then break end
	end

	if self.hover ~= hover then
		if self.hover then
			self:bubble_event(self.hover, "on_mouse_leave")
		end

		self.hover = hover

		if self.hover then
			self:bubble_event(self.hover, "on_mouse_enter")
		end
	end

	if self.active then
		-- Loop through active keys
		for key in pairs(self.key_down) do
			self:bubble_event(self.active, "on_key_down", key)
		end

		-- Loop through active mouse buttons
		for button, element in pairs(self.mouse_down) do
			if self.hover == element then
				self:bubble_event(self.active, "on_mouse_down", button)
			end
		end

		-- Loop through active joystick buttons
		for _, joystick in pairs(self.joystick_down) do
			for button in pairs(joystick.button) do
				self:bubble_event(self.active, "on_joystick_down", joystick, button)
			end

			for axis in pairs(joystick.axis) do
				self:bubble_event(self.active, "on_joystick_axis", joystick, axis, value)
			end

			for hat in pairs(joystick.hat) do
				self:bubble_event(self.active, "on_joystick_hat", joystick, hat, direction)
			end
		end

		-- Loop through active gamepad buttons
		for _k, gamepad in pairs(self.gamepad_down) do
			for button, value in pairs(gamepad) do
				self:bubble_event(self.active, "on_gamepad_down", gamepad, button, value)
			end
		end
	end
end

function GUI:draw()
	local function draw_element(element)
		self:_draw_element(element)

		if #element.children > 0 then
			for _, e in ipairs(element.children) do
				draw_element(e)
			end
		end
	end

	-- All root objects
	for _, element in ipairs(self.draw_order) do
		draw_element(element)
	end
end

function GUI:keypressed(key, isrepeat)
	if self.active then
		self.key_down[key] = true
		self:bubble_event(self.active, "on_key_pressed", key)
	end
end

function GUI:keyreleased(key)
	if self.active then
		self.key_down[key] = nil
		self:bubble_event(self.active, "on_key_released", key)
	end
end

function GUI:textinput(text)
	if self.active then
		self:bubble_event(self.active, "on_text_input", text)
	end
end

function GUI:mousepressed(x, y, button)
	local pressed = false

	local function check_binding(elements)
		for _, element in ipairs(elements) do
			if element:is_binding(x, y) then
				pressed = element
				check_binding(element.children)

				break
			end
		end
	end

	local i = #self.draw_order
	while i >= 1 do
		local element = self.draw_order[i]
		check_binding({ element })

		i = i - 1
		if pressed then break end
	end

	if pressed then
		if button == "wu" or button == "wd" then
			self:bubble_event(pressed, "on_mouse_scrolled", button)
		else
			self.mouse_down[button] = pressed
			pressed:set_focus(true)
			self:bubble_event(pressed, "on_mouse_pressed", button)
		end
	end
end

function GUI:mousereleased(x, y, button)
	local pressed = false

	local function check_binding(elements)
		for _, element in ipairs(elements) do
			if element:is_binding(x, y) then
				pressed = element
				check_binding(element.children)

				break
			end
		end
	end

	local i = #self.draw_order
	while i >= 1 do
		local element = self.draw_order[i]
		check_binding({ element })

		i = i - 1
		if pressed then break end
	end

	if pressed then
		self:bubble_event(pressed, "on_mouse_released", button)

		if self.mouse_down[button] == pressed then
			self:bubble_event(pressed, "on_mouse_clicked", button)
		end

		self.mouse_down[button] = nil
	end
end

function GUI:joystickadded(joystick)
	self.joystick_down[joystick]        = {}
	self.joystick_down[joystick].button = {}
	self.joystick_down[joystick].hat    = {}
	self.joystick_down[joystick].axis   = {}

	if joystick:isGamepad() then
		self.gamepad_down[joystick] = {}
	end

	if self.active then
		self:bubble_event(self.active, "on_joystick_added", joystick)
	end
end

function GUI:joystickremoved(joystick)
	self.joystick_down[joystick] = nil

	if joystick:isGamepad() then
		self.gamepad_down[joystick] = nil
	end

	if self.active then
		self:bubble_event(self.active, "on_joystick_removed", joystick)
	end
end

function GUI:joystickpressed(joystick, button)
	if self.active then
		self.joystick_down[joystick].button[button] = true
		self:bubble_event(self.active, "on_joystick_pressed", joystick, button)
	end
end

function GUI:joystickreleased(joystick, button)
	if self.active then
		self.joystick_down[joystick].button[button] = nil
		self:bubble_event(self.active, "on_joystick_released", joystick, button)
	end
end

function GUI:joystickaxis(joystick, axis, value)
	if self.active then
		self.joystick_down[joystick].axis[axis] = value
	end
end

function GUI:joystickhat(joystick, hat, direction)
	if self.active then
		self.joystick_down[joystick].hat[hat] = direction
	end
end

function GUI:gamepadpressed(joystick, button)
	if self.active then
		self.gamepad_down[joystick][button] = true
		self:bubble_event(self.active, "on_gamepad_pressed", joystick, button)
	end
end

function GUI:gamepadreleased(joystick, button)
	if self.active then
		self.gamepad_down[joystick][button] = nil
		self:bubble_event(self.active, "on_gamepad_released", joystick, button)
	end
end

function GUI:gamepadaxis(joystick, axis, value)
	if self.active then
		self.gamepad_down[joystick][axis] = value
	end
end

function GUI:resize(w, h)
	self:_apply_styles()
	Display.position_elements(self.draw_order)
end

function GUI:import_markup(file)
	-- This function will return true if every key is a properly formatted table
	-- This does not take into account if the proposed element is a valid element
	local function check_syntax(t, root)
		for k, v in ipairs(t) do
			-- All elements in root must be tables
			if root and type(v) ~= "table" then
				print("Invalid root")
				return false
			end

			-- Key 1 is reserved for the element type
			if not root and k == 1 and type(v) ~= "string" then
				print("Invalid type")
				return false
			end

			-- Key 2 can be the element value or a child element
			if type(v) == "table" then
				if not check_syntax(v) then return false end
			elseif k > 2 then
				print("Invalid child")
				return false
			end
		end

		return true
	end

	-- Loops through the markup to generate element objects
	-- Assign parent and child relationships when necessary
	local function create_object(t, parent)
		for k, v in ipairs(t) do
			if type(v) == "table" then
				local object = self:new_element(v, parent)
				create_object(v, object)
			end
		end
	end

	local markup

	if type(file) == "string" then
		markup = love.filesystem.load(file)
		assert(markup, string.format("Markup file (%s) not found.", file))
	else
		markup = function() return file end
	end


	local ok, err = pcall(markup)

	if ok then
		assert(check_syntax(err, true), string.format("File (%s) contains invalid markup.", file))
		create_object(err, false)
	end
end

function GUI:import_styles(file)
	local function parse_stylesheet(style, list, prepend)
		list = list or {}

		for _, query in ipairs(style) do
			-- Check all query selectors (no styles)
			if type(query) ~= "table" then
				if prepend then
					query = prepend .. " " .. query
				end

				local properties = {}

				-- Grab all of the properties (no nests!) from the style
				for property, value in pairs(style[#style]) do
					if type(property) ~= "number" then
						properties[property] = value
					end
				end

				local found = false

				-- If we already defined the style, append and overwrite new styles
				for i in ipairs(list) do
					if list[i].query == query then
						found = i
						break
					end
				end

				if not found then
					table.insert(list, { query=query, properties=properties })
				else
					for property, value in pairs(properties) do
						list[found].properties[property] = value
					end
				end

				-- If we have a nested table, do some recursion!
				for _, property in ipairs(style[#style]) do
					if type(property) == "table" then
						parse_stylesheet(property, list, query)
					end
				end
			end
		end

		return list
	end

	-- lol
	local global = {
		"bit", "math", "string", "table",
		"type", "tonumber", "tostring",
		"pairs", "ipairs", "getfenv",
		"pcall", "xpcall", "print",
		"next", "select", "unpack",
	}

	-- Sandbox
	local env = {}

	-- Some useful globals
	for _, v in ipairs(global) do
		env[v] = _G[v]
	end

	-- Import styles from another file
	env.import = function(file, styles)
		local import  = love.filesystem.load(file)
		local ok, err = pcall(import)

		if ok then
			env.append(import, styles)
		else
			error(err)
		end
	end

	-- Extend styles from one style to another
	-- This should search for a nested query if an ancestor is found
	--   Example: ".red .large" should search for a ".large" declaration within ".red"
	env.extend = function(from, to, styles)
		local function search(t, limit)
			for _, style in ipairs(styles) do
				for i, query in ipairs(style) do
					if query == t and (limit and i <= limit) then
						return style[#style]
					end
				end
			end
		end

		local f = search(from)
		local t = search(to, 1)

		env.mixin(f, t)
	end

	-- Mix styles into element
	env.mixin = function(from, to)
		for k, v in pairs(from) do
			if not to[k] then
				to[k] = v
			end
		end
	end

	-- Prepend data to a table
	env.prepend = function(from, to)
		for i, style in ipairs(from) do
			table.insert(to, i, style)
		end
	end

	-- Append data to a table
	env.append = function(from, to)
		for i, style in ipairs(from) do
			table.insert(to, style)
		end
	end

	local styles

	if type(file) == "string" then
		styles = love.filesystem.load(file)
		assert(styles, string.format("Styles file (%s) not found.", file))
	else
		styles = function() return file end
	end

	setfenv(styles, env)

	local ok, err = pcall(styles)

	if ok then
		local parsed

		-- Parse stylesheet
		for _, style in pairs(err) do
			parsed = parse_stylesheet(style, parsed)
		end

		-- Update global lookup
		for i, style in pairs(parsed) do

			local found = false

			for k in ipairs(self.styles) do
				if self.styles[k].query == style.query then
					found = k
					break
				end
			end

			if not found then
				table.insert(self.styles, { query=style.query, properties=style.properties })
			else
				for property, value in pairs(style.properties) do
					self.styles[found].properties[property] = value
				end
			end
		end

		self:_apply_styles()
	end
end

function GUI:import_scripts(file)
	-- lol
	local global = {
		"bit", "math", "string", "table",
		"type", "tonumber", "tostring",
		"pairs", "ipairs", "print",
		"pcall", "xpcall", "getfenv",
		"next", "select", "unpack",
	}

	-- Sandbox
	local env = {}

	-- Some useful globals
	for _, v in ipairs(global) do
		env[v] = _G[v]
	end

	env.gui = self

	local scripts

	if type(file) == "string" then
		scripts = love.filesystem.load(file)
		assert(scripts, string.format("Scripts file (%s) not found.", file))
	else
		scripts = function() return file end
	end

	setfenv(scripts, env)

	local ok, err = pcall(scripts)

	print(err)

	if ok then
	end
end

function GUI:new_element(element, parent, position)
	-- If we just want a default element, just pass in the element type!
	if type(element) == "string" then
		element = { element }
	end

	-- If no element type is found, don't create that element
	if not elements[element[1]] then return false end

	-- Create the element and insert it into the global elements list
	local object = setmetatable({}, { __index = elements[element[1]] })
	object:init(element, parent, self)
	table.insert(self.elements, object)

	if parent then
		-- If the element has a parent, send it along
		parent:add_child(object, position)
	else
		-- Otherwise, add it to the draw stack
		table.insert(self.draw_order, object)
	end

	return object
end

function GUI:set_active_element(element)
	if self.active_element then
		self.active:on_focus_leave()
	end

	self.active = element
	self.active:on_focus()

	return self.active
end

function GUI:get_active_element()
	return self.active
end

function GUI:get_elements_by_bounding(x, y)
	local filter = {}

	for _, element in ipairs(self.elements) do
		if element:is_binding(x, y) then
			table.insert(filter, element)
		end
	end

	return filter
end

function GUI:get_element_by_id(id, elements)
	elements = elements or self.elements

	for _, element in ipairs(elements) do
		if element.id == id then
			return element
		end
	end

	return false
end

function GUI:get_elements_by_type(type, elements)
	elements = elements or self.elements

	local filter = {}

	for _, element in ipairs(elements) do
		if element.type == type then
			table.insert(filter, element)
		end
	end

	return filter
end

function GUI:get_elements_by_class(class, elements)
	elements = elements or self.elements

	local filter = {}

	for _, element in ipairs(elements) do
		for _, eclass in ipairs(element.class) do
			if eclass == class then
				table.insert(filter, element)
				break
			end
		end
	end

	return filter
end

function GUI:get_elements_by_query(query, elements)
	elements = elements or self.elements

	-- https://love2d.org/forums/viewtopic.php?f=4&t=79562&p=179516#p179515
	local function get_groups(query)
		local groups = {}

		-- every group of one or more nonspace characters
		for match in query:gmatch("%S+") do
			local group = {
				elements = {},
				ids      = {},
				classes  = {},
				pseudos  = {},
			}

			-- match every keyword and their preceding but optional symbol
			for char, keyword in match:gmatch("([#%.:]?)([%w_]+)") do
				local category =          -- sort them by their symbol
				char == '#' and 'ids'     or
				char == '.' and 'classes' or
				char == ':' and 'pseudos' or
				'elements'                -- or lack thereof

				table.insert(group[category], keyword)
			end

			table.insert(groups, group)
		end

		return groups
	end

	local groups  = get_groups(query)
	local section = {}

	for k, group in ipairs(groups) do
		section[k] = elements

		if #group.ids > 0 then
			section[k] = { self:get_element_by_id(group.ids[1], section[k]) }
		end

		if #group.elements > 0 then
			section[k] = self:get_elements_by_type(group.elements[1], section[k])
		end

		if #group.classes > 0 then
			for _, class in ipairs(group.classes) do
				section[k] = self:get_elements_by_class(class, section[k])
			end
		end

		if #group.pseudos > 0 then
			for _, pseudo in ipairs(group.pseudos) do
				--[[
				Selector				Example					Example description
				-------------------------------------------------------------------
				:active					a:active				Selects the active link
				:checked				input:checked			Selects every checked <input> element
				:disabled				input:disabled			Selects every disabled <input> element
				:empty					p:empty					Selects every <p> element that has no children
				:enabled				input:enabled			Selects every enabled <input> element
				:first-child			p:first-child			Selects every <p> elements that is the first child of its parent
				:first-of-type			p:first-of-type			Selects every <p> element that is the first <p> element of its parent
				:focus					input:focus				Selects the <input> element that has focus
				:hover					a:hover					Selects links on mouse over
				:in-range				input:in-range			Selects <input> elements with a value within a specified range
				:invalid				input:invalid			Selects all <input> elements with an invalid value
				:lang(language)			p:lang(it)				Selects every <p> element with a lang attribute value starting with "it"
				:last-child				p:last-child			Selects every <p> elements that is the last child of its parent
				:last-of-type			p:last-of-type			Selects every <p> element that is the last <p> element of its parent
				:link					a:link					Selects all unvisited links
				:not(selector)			:not(p)					Selects every element that is not a <p> element
				:nth-child(n)			p:nth-child(2)			Selects every <p> element that is the second child of its parent
				:nth-last-child(n)		p:nth-last-child(2)		Selects every <p> element that is the second child of its parent, counting from the last child
				:nth-last-of-type(n)	p:nth-last-of-type(2)	Selects every <p> element that is the second <p> element of its parent, counting from the last child
				:nth-of-type(n)			p:nth-of-type(2)		Selects every <p> element that is the second <p> element of its parent
				:only-of-type			p:only-of-type			Selects every <p> element that is the only <p> element of its parent
				:only-child				p:only-child			Selects every <p> element that is the only child of its parent
				:optional				input:optional			Selects <input> elements with no "required" attribute
				:out-of-range			input:out-of-range		Selects <input> elements with a value outside a specified range
				:read-only				input:read-only			Selects <input> elements with a "readonly" attribute specified
				:read-write				input:read-write		Selects <input> elements with no "readonly" attribute
				:required				input:required			Selects <input> elements with a "required" attribute specified
				:root					root					Selects the document's root element
				:target					#news:target			Selects the current active #news element (clicked on a URL containing that anchor name)
				:valid					input:valid				Selects all <input> elements with a valid value
				:visited				a:visited				Selects all visited links
				--]]

				if pseudo == "last" then
					section[k] = { section[k][#section[k]] }
				end

				if pseudo == "root" then
					local filter = {}
					for _, element in ipairs(section[k]) do
						if not element.parent then
							table.insert(filter, element)
						end
					end
					section[k] = filter
				end
			end
		end
	end

	-- Search family for a particular element
	local function check_hierarchy(element, seek)
		local element = element.parent

		if element then
			if element == seek then
				return true
			else
				return check_hierarchy(element, seek)
			end
		end

		return false
	end

	local filter = {}

	-- Build a filter based on hierarchy
	for i=1, #section do
		local current = #section - i + 1
		local parent = current - 1
		local finish  = 1

		-- If there is no descendent selector, just return the group
		if #section == 1 then
			return section[1]
		elseif parent > 0 then
			for _, element in ipairs(section[current]) do
				for _, parent in ipairs(section[parent]) do
					if check_hierarchy(element, parent) then
						table.insert(filter, element)
					end
				end
			end
		end
	end

	return filter
end

function GUI:bubble_event(element, event, ...)
	if element[event] then
		if ... then
			element[event](element, unpack({ ... }))
		else
			element[event](element)
		end
	elseif element.parent then
		self:bubble_event(element.parent, event, ...)
	end
end

function GUI:_apply_styles()
	-- Apply default properties
	for _, element in ipairs(self.elements) do
		element.properties = {}

		for property, value in pairs(element.default_properties) do
			element.properties[property] = value
		end
	end

	-- Apply query properties
	for _, style in ipairs(self.styles) do
		local filter = self:get_elements_by_query(style.query)

		for _, element in ipairs(filter) do
			for property, value in pairs(style.properties) do
				element.properties[property] = value
			end
		end
	end

	-- Apply custom properties
	for _, element in ipairs(self.elements) do
		for property, value in pairs(element.custom_properties) do
			element.properties[property] = value
		end
	end
end

function GUI:_draw_element(element)
	--[[         ~~ BOX MODEL ~~

	    {             WIDTH             }
	+---------------------------------------+
	|                MARGIN                 |
	|   +-------------------------------+   | ~~~
	|   |/////////// BORDER ////////////|   |
	|   |///+-----------------------+///|   |
	|   |///|        PADDING        |///|   |  H
	|   |///|   +---------------+   |///|   |  E
	|   |///|   |               |   |///|   |  I
	|   |///|   |    CONTENT    |   |///|   |  G
	|   |///|   |               |   |///|   |  H
	|   |///|   +---------------+   |///|   |  T
	|   |///|        PADDING        |///|   |
	|   |///+-----------------------+///|   |
	|   |/////////// BORDER ////////////|   |
	|   +-------------------------------+   | ~~~
	|                MARGIN                 |
	+---------------------------------------+
	    {             WIDTH             }

	--]]
	local ep = element.properties

	-- Position & size of element
	local x = element.position.x
	local y = element.position.y
	local w = ep.width
	local h = ep.height

	-- Content start & end of element
	local cx = x + ep.padding[4] + ep.border[4]
	local cy = y + ep.padding[1] + ep.border[1]
	local cw = w - ep.padding[1] - ep.border[1] - ep.padding[2] - ep.border[2]
	local ch = h - ep.padding[4] - ep.border[4] - ep.padding[3] - ep.border[3]

	-- Draw box
	love.graphics.rectangle("line", x, y, w, h)

	-- Set text color
	if ep.text_color then
		love.graphics.setColor(ep.text_color)
	end

	-- Draw text within content area
	love.graphics.printf(tostring(element.value), cx, cy, cw)
	love.graphics.setColor(255, 255, 255, 255)

	-- DEBUG
	love.graphics.setColor(255, 255, 0, 63)
	love.graphics.rectangle("line", x-ep.margin[4], y-ep.margin[1], w+ep.margin[4]+ep.margin[2], h+ep.margin[1]+ep.margin[3])
	love.graphics.setColor(0, 255, 255, 63)
	love.graphics.rectangle("line", cx, cy, cw, ch)
	love.graphics.setColor(255, 255, 255, 255)
	-- DEBUG
end

return GUI
