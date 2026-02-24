local GITHUB_RAW = "https://raw.githubusercontent.com/MisileLab/minecrafts/main/radar/angle"
local FILES = {
  "config",
  "scanner",
  "transmitter",
  "startup",
}

local function download(url, path)
  local response = http.get(url)
  if not response then
    return false, "Failed to fetch: " .. url
  end

  local content = response.readAll()
  response.close()

  if not content then
    return false, "Empty response from: " .. url
  end

  local file = fs.open(path, "w")
  if not file then
    return false, "Failed to write: " .. path
  end

  file.write(content)
  file.close()

  return true
end

local function install()
  print("=== Angle Transmitter Installer ===")
  print("Downloads angle transmitter for rotating platform")
  print("")

  local success = 0
  local failed = 0

  for _, name in ipairs(FILES) do
    local url = GITHUB_RAW .. "/" .. name
    local path = name
    local ok, err = download(url, path)

    if ok then
      print("[OK] " .. name)
      success = success + 1
    else
      print("[FAIL] " .. name .. ": " .. err)
      failed = failed + 1
    end
  end

  print("")
  print("Done! " .. success .. " files downloaded, " .. failed .. " failed.")

  if failed == 0 then
    print("")
    print("Place this computer on Phys Bearing rotating platform.")
    print("Connect Ender Modem to '" .. "back" .. "' (or edit config)")
    print("Run 'startup' to begin transmitting angles.")
  end

  return failed == 0
end

local args = {...}
if args[1] == "update" then
  print("=== Angle Updater ===")
  install()
else
  install()
end
