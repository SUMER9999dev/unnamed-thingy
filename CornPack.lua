local LuauClass = (function() local function a(b,...)local c={...}return function(...)return b(unpack(c),...)end end;local function d(b)local e={}for f,g in next,b do e[f]=g end;return e end;local function h(b,i)local b=d(b)for f,g in next,i do if type(f)=='number'then table.insert(b,g) continue end;b[f]=g end;return b end;local j={}j._should_init=false;j.super=nil;j._type=nil;function j.new(k,...)k.__index=k;local self=setmetatable({},k)if k.super then k.super._should_init=false;self.super=k.super.new()end;if k._should_init then self:__init(...)end;return self end;local l={}l.__index=l;function l.__call(self,k)local k=k or{}local m=k._type or''local n=d(j)n._type=m;n._should_init=true;n=h(n,k)n.new=a(j.new,n)return n end;function l:extend(o,p)local p=p or{}local o=d(o)p.super=o;p=h(o,p)return self(p)end;return setmetatable({},l) end)()


local Packer = LuauClass {_type = 'Packer'}

function Packer:__init()
end

function Packer:url_as_loadstring(url)
    return string.format('loadstring(game:HttpGet(\'%s\'))()', url)
end

function Packer:url_as_raw(url)
    return string.format('(function() %s end)()', game:HttpGet(url))
end

function Packer:file_as_raw(path)
    return string.format('(function() %s end)()', readfile(path))
end


local Macros = LuauClass {__type = 'Macros'}

function Macros:__init(line, name, argument)
    self._line = line
    self._start_symbol = 0

    self._name = name:lower()
    self._argument = argument
end

function Macros:__tostring()
    return string.format('%s("%s")', self._name, self._argument)
end


local Analyzer = LuauClass {__type = "analLizando"}

function Analyzer:__init()
end

function Analyzer:__get_macros_and_argument(text)
    local name, argument = text:gmatch('CORN_(.*)%([\'"](.*)[\'"]%)')()
    return name, argument
end

function Analyzer:__make_line_formatable(line, macros)
    local formatable_line = string.gmatch(line, '(.+)'..'CORN_'..macros)()..'%s'
    return formatable_line
end

function Analyzer:__analyze_line(line)
    if line:find("CORN") then
       return self:__get_macros_and_argument(line)
    end

    return nil, nil
end

function Analyzer:analyze(source)
    self._source = source
    self.__splitted_lines = self._source:split("\n")

    local macros_buffer = {}
    local formatable_source = ''

    for line_number, line in pairs(self.__splitted_lines) do
        local macros, argument = self:__analyze_line(line)

        if not macros then
            formatable_source = formatable_source .. line .. "\n"
            continue
        end

        local formatable_line = self:__make_line_formatable(line, macros)
        formatable_source = formatable_source .. formatable_line .. "\n"

        table.insert(macros_buffer, Macros.new(line_number, macros, argument))
    end

    return {formatable_source = formatable_source, macros_list = macros_buffer}
end


local Builder = LuauClass {_type = 'Builder'}

function Builder:__init(options)
    if not options then
        return error('You can\'t use Builder without options.')
    end

    self.__main = options.main or error('You must specify main in options.')
    self.__output = options.output or 'builds'

    if not isfile(self.__main) then
        return error('Main file does not exist')
    end

    self.__analyzer = options.analyzer or Analyzer.new()
    self.__packer = options.packer or Packer.new()
end

function Builder:__create_output_folder_if_not_exists()
    if isfolder(self.__output) then
        return
    end

    makefolder(self.__output)
end

function Builder:__save_build(name, build_source)
    writefile(self.__output..'/'..name, build_source)
end

function Builder:__create_build_name()
    local date = os.date('%H_%M_%m.%d.%Y')
    return 'build_'..date..'.lua'
end

function Builder:__get_packed(macros_list)
    local format_buffer = {}

    for _, macros in pairs(macros_list) do
        local result = ''

        if macros._name == 'from_file' then
            result = self.__packer:file_as_raw(macros._argument)
        end

        if macros._name == 'from_url' then
            result = self.__packer:url_as_loadstring(macros._argument)
        end

        if macros._name == 'from_url_raw' then
            result = self.__packer:url_as_raw(macros._argument)
        end

        table.insert(format_buffer, result)
    end

    return format_buffer
end

function Builder:build()
    local start_time = os.time()

    local source = readfile(self.__main)
    local name = self:__create_build_name()
    local analyze_result = self.__analyzer:analyze(source)
    local packed_libraries = self:__get_packed(analyze_result.macros_list)

    self:__create_output_folder_if_not_exists()

    source = analyze_result.formatable_source:format(
        table.unpack(packed_libraries)
    )

    self:__save_build(name, source)

    local end_time = os.time()

    print(string.format(
        '[CornPack]: took %s seconds to build.',
        end_time - start_time
    ))
end


return Builder
