--[[
    A library for generating ULIDs
]]

--[[
    Copyright © 2024 plainenglish

    Permission is hereby granted, free of charge, to any person obtaining a copy
    of this software and associated documentation files (the “Software”), to
    deal in the Software without restriction, including without limitation the
    rights to use, copy, modify, merge, publish, distribute, sublicense, and/or
    sell copies of the Software, and to permit persons to whom the Software is
    furnished to do so, subject to the following conditions:

    The above copyright notice and this permission notice shall be included in
    all copies or substantial portions of the Software.

    THE SOFTWARE IS PROVIDED “AS IS”, WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
    IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
    FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
    AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
    LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING
    FROM, OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS
    IN THE SOFTWARE.
]]

local ENCODING = string.split("0123456789ABCDEFGHJKMNPQRSTVWXYZ", "");
local ENCODING_LEN = #ENCODING;
local TIME_MAX = 2^48 - 1;
local TIME_LEN = 10;
local RANDOM_LEN = 16;

local STRINGS = {
    ERR_INSECURE = "no secure secure prng available! either enable 'allow_insecure' to continue or provide a custom prng function within the 'dependencies' option!",
    ERR_IMPRECISE = "no milisecond-precise time function available! either enable 'allow_imprecice' or provide a custom time function within the 'dependencies' option!",
    ERR_UNSUPPORTED_LIB = "runtime library '%s' unavailable",

    WARN_INSECURE = "no secure prng available.",
    WARN_UNKNOWN_RUNTIME = "unknown runtime provided.",
};

type PartialGeneratorOptions = {
    monotonic: boolean?,
    dependencies: Dependencies?,
    allow_insecure: boolean?,
    allow_imprecise: boolean?
};

type GeneratorOptions = {
    monotonic: boolean,
    dependencies: Dependencies,
    allow_insecure: boolean,
    allow_imprecise: boolean
};

local DEFAULT_GENERATOR_OPTIONS: GeneratorOptions = {
    monotonic = false, -- Switch when (if) monotonic is implemeneted
    dependencies = nil :: any, -- This'll be provided downstream.
    allow_insecure = false,
    allow_imprecise = false,
};

type Dependencies = {
    now: () -> number,
    prng: (min: number, max: number) -> number,
};

local function rt_import(lib_name: string): any
    local ok, lib = pcall(require, lib_name);

    if not ok then
        error(STRINGS.ERR_UNSUPPORTED_LIB:format(lib_name));
    end

    return lib;
end

--[=[
    Gets runtime dependent functions.

    @yields
    @private
    
    @param allow_insecure boolean -- Whether to panic if no secure prng is found
    @param allow_imprecise boolean -- Whether to panic if no precise time fn is found
    @return Dependencies -- A dictionary of runtime dependent functiions
    
    @error insecure -- Throws if no secure prng is found, can be suppressed with the 'allow_insecure' option
    @error imprecise -- Throws if no precise time function is found, can be suppressed with the 'allow_imprecise' option
]=]
local function get_dependencies(allow_insecure: boolean, allow_imprecise: boolean): Dependencies
    local function insecure()
        if not allow_insecure then
            error(STRINGS.ERR_INSECURE);
        end
    end

    local function imprecise()
        if not allow_imprecise then
            error(STRINGS.ERR_IMPRECISE);
        end
    end

    if game and task then -- ROBLOX
        insecure();

        return {
            now = function(): number
                return DateTime.now().UnixTimestampMillis;
            end,
            prng = math.random,
        };
    elseif pcall(require, "@lune/datetime") then -- Lune
        insecure();

        local datetime = rt_import("@lune/datetime");
        
        return {
            now = function(): number
                return datetime.now().unixTimestampMillis;
            end,
            prng = math.random,
        };
    elseif pcall(require, "@zcore/datetime") then
        local datetime = rt_import("@zcore/datetime");
        local crypto = rt_import("@zcore/crypto");

        return {
            now = function(): number
                return datetime.now().unixTimestampMillis;
            end,
            prng = crypto.random.nextInteger,
        };
    else
        insecure();
        imprecise();

        return {
            now = function(): number
                return math.round(os.time() * 1000);
            end,
            prng = math.random,
        };
    end
end

--[=[
    Generates a ULID

    @yields

    @param time number? -- An optional time seed
    @return string -- The ULID

    @error max_reached -- Throws if the maximum number of ULIDs have been generated this milisecond (if monotonic)
]=]
local function __generator(time: number?): string
    return nil :: any;
end

--[=[
    Library for generating [Universally Unique Lexicographically Sortable Identifiers](https://github.com/ulid/spec)

    @class ulid
]=]
local ulid = {};

--[=[
    Creates a ULID generator function

    ### Example
    ```lua
    local ulid = ulid.generator({ allow_insecure = true });

    ulid(); --> 01ARZ3NDEKTSV4RRFFQ69G5FAV
    ulid(); --> 01BX5ZZKBKACTAV9WEVGEMMVS0
    ```

    @within ulid
    @yields

    @param options PartialGeneratorOptions? -- Options to configure the generator
    @return (time: number?) -> string -- Generator function

    @error insecure -- Throws if no secure prng is found, can be suppressed with the 'allow_insecure' option
    @error imprecise -- Throws if no precise time function is found, can be suppressed with the 'allow_imprecise' option
]=]
function ulid.generator(options: PartialGeneratorOptions?): typeof(__generator)
    local _options: GeneratorOptions = (options :: any) or DEFAULT_GENERATOR_OPTIONS;

    for k, v in DEFAULT_GENERATOR_OPTIONS do
        if _options[k] == nil then
            _options[k] = v;
        end
    end
    
    local dependencies = _options.dependencies or get_dependencies(
        _options.allow_insecure,
        _options.allow_imprecise
    );

    local now = dependencies.now;
    local prng = dependencies.prng;

    local function random_char(): string
        local char_idx = prng(1, ENCODING_LEN);
        return ENCODING[char_idx];
    end

    local function encode_random(): string
        local str = "";

        for i = 1, RANDOM_LEN do
            str ..= random_char();
        end
        
        return str;
    end

    local function encode_time(time: number): string
        assert(time == time, "time is NaN");
        assert(time <= TIME_MAX, "cannot encode time greater than " .. TIME_MAX);
        assert(time >= 0, "time must be positive");
        assert(math.round(time) == time, "time must be an integer");
    
        local str = "";

        for i = 1, TIME_LEN do
            local mod = time % ENCODING_LEN;
            str = ENCODING[mod+1] .. str;
            time = (time - mod) / ENCODING_LEN;
        end

        return str;
    end

    if _options.monotonic then
        error("monotonic generators are unsupported at this time");
    else
        return function(time: number?)
            return encode_time(time or now()) .. encode_random();
        end
    end
end

--[=[
    Creates a ULID generator function

    ### Example
    ```lua
    ulid.ulid(nil, true); --> 01ARZ3NDEKTSV4RRFFQ69G5FAV
    ulid.ulid(nil, true); --> 01BX5ZZKBKACTAV9WEVGEMMVS0
    ```

    @within ulid
    @yields


    @param allow_insecure_and_imprecise boolean? -- Whether to suppress insecure/imprecise errors
    @return string -- The ULID

    @error insecure -- Throws if no secure prng is found, can be suppressed with the 'allow_insecure' option
    @error imprecise -- Throws if no precise time function is found, can be suppressed with the 'allow_imprecise' option
]=]
function ulid.ulid(time: number?, allow_insecure_and_imprecise: boolean?): string
    return ulid.generator({
        allow_insecure = allow_insecure_and_imprecise,
        allow_imprecise = allow_insecure_and_imprecise,
    })(time);
end

return ulid;