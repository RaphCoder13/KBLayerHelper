#NoEnv
#SingleInstance, Force

; --- Script Info ---
script_title := "KBLayerHelper"
script_version := "18/01/2023 (JSON Mod v1)" ;// JSON Change: Updated version note
script_author := "Raph.Coder"
;;// JSON Change: Replaced INI path with JSON path
global jsonConfigFile := A_ScriptDir "\"  "config.json"
global Config ;// JSON Change: Global object to hold parsed JSON config

; --- Includes & Settings ---
#Include AHKHID.ahk ; Assurez-vous que AHKHID.ahk est accessible
;// JSON Change: Include JSON library
#Include JSON.ahk   ; Assurez-vous que JSON.ahk est accessible

SetBatchLines, -1
SetWorkingDir, %A_ScriptDir%

; --- Global Variables (will be populated by LoadConfigFromJson) ---
global VendorId, ProductId
global DisplayLayout, LayoutSize, LayoutPosition, LayoutFontSize, LayoutDuration, LayoutTransparency
global DisplayLayerName, LayerNameSize, LayerNamePosition, LayerNameFontSize, LayerNameDuration, LayerNameTransparency
global NoDisplayTimeout, LockHotKey, LayerArray, LayoutDisplayHotKey
global MomentaryLayoutDisplayHotKey, MomentaryLayoutDisplayDuration, MomentaryTimerRunning
global LastLayerIdx
global InputQueue := [] ; Queue to store input messages
global ProcessingInput := false ; Flag to indicate if the queue is being processed
MomentaryTimerRunning := 0

; --- Load Configuration ---
;// JSON Change: Call the new JSON loading function
LoadConfigFromJson()
if !IsObject(Config) ; Check if loading failed
    ExitApp ; Error message would have been shown in LoadConfigFromJson

; --- Setup Hotkeys ---
;// JSON Change: No change needed here, uses global variables populated from JSON
Hotkey, %LockHotKey%, ChangeNoDisplayTimeout, on
Hotkey, %LayoutDisplayHotKey%, ChangeDisplayLayout, on
Hotkey, %MomentaryLayoutDisplayHotKey%, MomentaryLayoutDisplay, on

; --- Construct Tray Icon Menu ---
Menu Tray, NoStandard
Menu Tray, Add, Show Layout, ChangeDisplayLayout
Menu Tray, Add, Show Layer Name, ChangeDisplayLayerName
Menu Tray, Add, No timeout, ChangeNoDisplayTimeout

Menu Tray, Add ; separator
Menu Tray, Add, Reload %script_title%, Reload
Menu Tray, Add, Exit %script_title%, Exit

;// JSON Change: No change needed here, uses global variables populated from JSON
if DisplayLayout
    Menu Tray, Check, Show Layout

if DisplayLayerName
    Menu Tray, Check, Show Layer Name

if NoDisplayTimeout
    Menu Tray, Check, No timeout ; Corrected typo 'timeoutr' to 'timeout'


;--- Set up AHKHID ---
AHKHID_UseConstants()
usagePage := 65329 ; Keep these constants as they were
usage := 116

Gui, mainGUI:New, +LastFound +AlwaysOnTop -Border -SysMenu -Caption +ToolWindow
GuiHandle := WinExist()

OnMessage(0x00FF, "InputMsg",1) ; Intercept WM_INPUT
result := AHKHID_Register(usagePage, usage, GUIHANDLE, RIDEV_INPUTSINK)
if (!result)
    OutputDebug, % "AHKHID_Register succeeded for usagePage=" usagePage ", usage=" usage
else
    OutputDebug, % "AHKHID_Register failed for usagePage=" usagePage ", usage=" usage

Gui, mainGUI:Show

; --- Set Initial Tray Icon ---
;// JSON Change: Set initial tray icon based on the first layer found in JSON.
;// Assumes the first layer in the JSON array is the default/base layer (index 1).
Try {
    firstLayerKey := Config.Layers[1].Reference ? Config.Layers[1].Reference : 1
    SetTrayIcon(LayerArray[firstLayerKey].ico)
} Catch e {
    MsgBox, 48, Erreur Initiale, Impossible de définir l'icône initiale. Vérifiez la section 'Layers' dans %jsonConfigFile%.`nDétails: e.Message
}
Return

; ==============================================================================
;// JSON Change: New function to load configuration from JSON
; ==============================================================================
LoadConfigFromJson()
{
    global Config ; Make all assignments global by default in this function scope

    if !FileExist(jsonConfigFile)
    {
        MsgBox, 48, Erreur, Le fichier de configuration JSON '%jsonConfigFile%' est introuvable.
        Return 0 ; Indicate failure
    }

    FileRead, jsonString, %jsonConfigFile%
    if (ErrorLevel)
    {
        MsgBox, 48, Erreur, Impossible de lire le fichier JSON '%jsonConfigFile%'.
        Return 0 ; Indicate failure
    }

    Try
    {
        Config := JSON.Load(jsonString) ; Assign to global Config object
    }
    Catch e
    {
         MsgBox, 48, Erreur de JSON, Le fichier '%jsonConfigFile%' contient un JSON invalide.`n`nDetails: e.Message "`nLigne: " e.Line "`nPosition: " e.Pos "`nSource: " e.Source
         Return 0 ; Indicate failure
    }

    ; --- Populate Global Variables from Config Object ---
    Try {
        ; [Device]
        VendorId := Config.Device.VendorId
        ProductId := Config.Device.ProductId

        ; [General]
        NoDisplayTimeout := Config.General.NoDisplayTimeout
        LockHotKey := Config.General.LockHotKey
        LayoutDisplayHotKey := Config.General.LayoutDisplayHotKey
        MomentaryLayoutDisplayHotKey := Config.General.MomentaryLayoutDisplayHotKey
        MomentaryLayoutDisplayDuration := Config.General.MomentaryLayoutDisplayDuration

        ; [Layout]
        DisplayLayout := Config.Layout.DisplayLayout
        LayoutPosition := Config.Layout.Position ; Directly assign the array [x, y]
        LayoutSize := Config.Layout.Size         ; Directly assign the array [w, h]
        LayoutFontSize := Config.Layout.FontSize
        LayoutTransparency := Config.Layout.Transparency
        LayoutDuration := Config.Layout.Duration

        ; [LayerName]
        DisplayLayerName := Config.LayerName.DisplayLayerName
        LayerNamePosition := Config.LayerName.Position ; Directly assign the array [x, y]
        LayerNameSize := Config.LayerName.Size         ; Directly assign the array [w, h]
        LayerNameFontSize := Config.LayerName.FontSize
        LayerNameDuration := Config.LayerName.Duration
        LayerNameTransparency := Config.LayerName.Transparency

        ; [Layers] - Build the associative array expected by the script
        ; LayerArray := BuildLayerArrayFromJson()

        For _, device in Config.Devices
        {
            OutputDebug, % TEXT "Device: " device.Name
            For _, pid in device.ProductIds
            {
                OutputDebug, % TEXT "  ProductId: " pid ; Format as hexadecimal with leading zeros and 4 digits, e.g., 0001 for
            }
        }
    } Catch e {
        MsgBox, 48, Erreur de Configuration, Clé manquante ou invalide dans '%jsonConfigFile%'. Vérifiez la structure.`nDétails: e.What " -> " e.Message
        Config := "" ; Invalidate config object on error
        Return 0 ; Indicate failure
    }

    Return 1 ; Indicate success
}

; ==============================================================================
;// JSON Change: Helper function to build LayerArray from JSON data
; ==============================================================================
BuildLayerArrayFromJson() {
    global Config
    tempLayerArray := {} ; Use an object (associative array)

    if !Config.HasKey("Layers") || !IsObject(Config.Layers) || Config.Layers.Length() = 0 {
        MsgBox, 48, Erreur Configuration, La section 'Layers' est manquante ou vide dans %jsonConfigFile%.
        Return {} ; Return empty object on error
    }

    For index, layerObj in Config.Layers
    {
        ; Determine the key: Use 'Reference' if not empty, otherwise use the 1-based index.
        key := Trim(layerObj.HasKey("Reference") ? layerObj.Reference : "")
        if (key = "") {
            key := index ; Use the 1-based loop index
        }

        ; Check for required keys in each layer object
        if !(layerObj.HasKey("Name") && layerObj.HasKey("Icon") && layerObj.HasKey("Image")) {
             MsgBox, 48, Erreur Configuration, Layer %index% (Key: %key%) manque Name, Icon, ou Image dans %jsonConfigFile%.
             Continue ; Skip this invalid layer entry
        }

        ; Match the structure expected by InputMsg: {label: ..., ico: ..., image: ...}
        tempLayerArray[key] := { label: layerObj.Name, ico: layerObj.Icon, image: layerObj.Image }
    }
    Return tempLayerArray
}

; ==============================================================================
;// JSON Change: New function to save configuration changes back to JSON
; ==============================================================================
SaveConfigToJson() {
    global Config, jsonConfigFile, NoDisplayTimeout, DisplayLayout, DisplayLayerName

    if !IsObject(Config) {
        MsgBox, 48, Erreur Sauvegarde, L'objet de configuration n'est pas valide. Sauvegarde annulée.
        Return
    }

    ; Update the Config object with current state variables that can be changed via Tray Menu
    Try {
        Config.General.NoDisplayTimeout := NoDisplayTimeout
        Config.Layout.DisplayLayout := DisplayLayout
        Config.LayerName.DisplayLayerName := DisplayLayerName
    } Catch e {
         MsgBox, 48, Erreur Sauvegarde, Erreur lors de la mise à jour de l'objet Config avant sauvegarde.`nDétails: e.Message
         Return
    }

    ; Dump the updated Config object to JSON string (pretty print with 4 spaces indent)
    jsonString := JSON.Dump(Config, "", 4)

    ; Save the string to the file (overwrite)
    Try {
        file := FileOpen(jsonConfigFile, "w", "UTF-8") ; Open for writing, overwrite, UTF-8
        if IsObject(file) {
            file.Write(jsonString)
            file.Close()
        } else {
            MsgBox, 48, Erreur Sauvegarde, Impossible d'ouvrir '%jsonConfigFile%' pour écriture.
        }
    } Catch e {
        MsgBox, 48, Erreur Sauvegarde, Erreur lors de l'écriture dans '%jsonConfigFile%'.`nDétails: e.Message
    }
}

; ==============================================================================
;// JSON Change: Deleted the old ReadIniFile() function
; ==============================================================================


; ==============================================================================
; --- AHKHID Input Message Handling --- (Updated to support multiple devices)
; ==============================================================================
InputMsg(wParam, lParam, msg) {

    local r, h, resData, iVendorID, iProductID, uData, stringMsg

    Critical ; Ensure the function runs without interruption
    ; Add the input message to the queue
    r := AHKHID_GetInputInfo(lParam, II_DEVTYPE)
    h := AHKHID_GetInputInfo(lParam, II_DEVHANDLE)
    resData := AHKHID_GetInputData(lParam, uData)
    iVendorID := AHKHID_GetDevInfo(h, DI_HID_VENDORID, True)
    iProductID :=  Format("{:#06x}", AHKHID_GetDevInfo(h, DI_HID_PRODUCTID, True))
    If (r = RIM_TYPEHID && iVendorID = VendorId) {
        offset := 0x1 ; Verify this offset is still correct for your device data
        stringMsg := Trim(StrGet(&uData + offset, "UTF-8"), "`t`n`r")
        InputQueue.Push({r: r, h: h,  iVendorID: iVendorID, iProductID: iProductID, stringMsg: stringMsg})
        ; Start processing the queue if not already running
        if (!ProcessingInput) {
            ProcessingInput := true
            SetTimer, ProcessInputQueue, -1 ; Start processing the queue
        }
    }
    Return
}

ProcessInputQueue() {
    global InputQueue, ProcessingInput
    while (InputQueue.Length() > 0)
    {
        ; Get the next message from the queue
        input := InputQueue.RemoveAt(1)
        ; Process the input message
        HandleInputMessage(input.r, input.h, input.iVendorID, input.iProductID, input.stringMsg)
    }
    ProcessingInput := false ; Mark processing as complete
}

HandleInputMessage(r, h, iVendorID, iProductID, stringMsg) {
    local foundPos, idx, resData

    ; OutputDebug, % TEXT "HandleInputMessage called({r: " r ", h: " h ",  iVendorID: " iVendorID ", iProductID: " iProductID ", stringMsg: " stringMsg "})"
    ; If (r = RIM_TYPEHID) {
    ;     ; Check if VendorId and ProductId match the configuration
    ;     if (iVendorID = VendorId) {
            deviceConfig := GetDeviceConfigByProductId(iProductID)
            if (!IsObject(deviceConfig)) {
                ToolTip, Unknown ProductId: %iProductID%
                SetTimer, ToolTipOff, -2000
                Return
            }


            LayerArray := BuildLayerArrayFromDeviceConfig(deviceConfig)

            Loop, Parse, stringMsg, `n, `r
            {
                foundPos := InStr(A_LoopField, "KBHLayer")
                If (foundPos > 0) {
                    idx := SubStr(A_LoopField, 8 + foundPos)
                    if LayerArray.HasKey(idx) {
                        if (LastLayerIdx != idx) {
                            LastLayerIdx := idx
                            SetTrayIcon(LayerArray[idx].ico)

                            if (DisplayLayout)
                                ShowLayoutOSD(LayerArray[idx].label, LayerArray[idx].image)
                            if (DisplayLayerName)
                                ShowLayerNameOSD(LayerArray[idx].label)
                        }
                    }
                }
            }
    ;     }
    ; }
}

; Helper function to get device configuration by ProductId
GetDeviceConfigByProductId(productId) {
    global Config
    if !IsObject(Config.Devices)
        Return ""

    For _, device in Config.Devices
    {

        ; if (device.ProductIds.HasKey(Format("0x{:X}", productId)) )
        For k, v in device.ProductIds
        {
            if (v == productId)
            {
                Return device
            }
        }
    }
    Return "" ; Return empty if no matching device is found
}

; Helper function to build LayerArray from a specific device configuration
BuildLayerArrayFromDeviceConfig(deviceConfig) {
    tempLayerArray := {} ; Use an object (associative array)

    if !IsObject(deviceConfig.Layers) || deviceConfig.Layers.Length() = 0 {
        MsgBox, 48, Erreur Configuration, La section 'Layers' est manquante ou vide pour le périphérique.
        Return {} ; Return empty object on error
    }

    For index, layerObj in deviceConfig.Layers {
        ; Determine the key: Use 'Reference' if not empty, otherwise use the 1-based index.
        key := Trim(layerObj.HasKey("Reference") ? layerObj.Reference : "")
        if (key = "") {
            key := index ; Use the 1-based loop index
        }

        ; Check for required keys in each layer object
        ; if !(layerObj.HasKey("Name") && layerObj.HasKey("Icon") && layerObj.HasKey("Image")) {
        ;      MsgBox, 48, Erreur Configuration, Layer %index% (Key: %key%) manque Name, Icon, ou Image.
        ;      Continue ; Skip this invalid layer entry
        ; }

        ; Match the structure expected by InputMsg: {label: ..., ico: ..., image: ...}
        tempLayerArray[key] := { label: layerObj.Name, ico: layerObj.Icon, image: layerObj.Image }
    }
    Return tempLayerArray
}

ToolTipOff() {
    ToolTip
}


; ==============================================================================
; --- OSD Display Functions --- (Minor changes for array access)
; ==============================================================================

SetTrayIcon(iconname){
    If FileExist(iconname)
        Menu, Tray, Icon, %iconname%
    ; Else
    ;     Menu, Tray, Icon, %A_AhkPath%, 2 ; Default icon if file not found
}

ShowLayerNameOSD(key){
    static layerNameTxtID, layerNamePictureID ; Keep static variables
    if(key == "")
    {
        return 0
    }

    ;// JSON Change: Access array elements using .1 and .2 (or [1] and [2])
    width := LayerNameSize.1
    height := LayerNameSize.2

    ComputePosition(LayerNamePosition.1, LayerNamePosition.2, width, height, xPlacement, yPlacement)

    if !WinExist("layerGUI")
    {
        Gui, indicatorLayer:New, +LastFound +AlwaysOnTop -Border -SysMenu +Owner -Caption +ToolWindow +E0x08000000, layerGUI
        Gui, indicatorLayer:Color, FF0000 ; Consider making this color configurable?
        Gui, indicatorLayer:Margin, 0, 0
        Gui, indicatorLayer:Font, s%LayerNameFontSize% cWhite, Verdana ; Consider making font/color configurable?
        Gui, indicatorLayer:Add, Text, x0 y0 w%width% h%height% BackGroundTrans Center vlayerNameTxtID, %key%
    }
    else
    {
        GuiControl, indicatorLayer:Text, layerNameTxtID, %key%
    }

    Gui, indicatorLayer:Show, x%xPlacement% y%yPlacement% NoActivate AutoSize
    Winset, ExStyle, +0x20
    WinSet, Transparent, %LayerNameTransparency%
    SetTimer, HideLayerNameOSD, -%LayerNameDuration%
}

ShowLayoutOSD(key, image){
    static layoutNameID, layoutPicture, myPict ; Need Hwnd for ControlGetPos

    if (!FileExist(image))
    {
        return 0
    }
    ;// JSON Change: Access array elements using .1 and .2 (or [1] and [2])
    width := LayoutSize.1
    height := LayoutSize.2

    If !WinExist("layoutGUI")
    {
        Gui, layoutLayer:New, +LastFound +AlwaysOnTop -Border -SysMenu +Owner -Caption +ToolWindow +E0x08000000, layoutGUI
        Gui, layoutLayer:Margin, 0, 0

        oWidth := width
        oHeight := height
        if FileExist(image)
        {
            ; Add picture and get its HWND for size calculation
            Gui, layoutLayer:Add, Picture, HwndmyPict vlayoutPicture AltSubmit BackgroundTrans, %image%
            ControlGetPos,,,iWidth,iHeight,, ahk_id %myPict%

            ; Aspect ratio calculation (seems correct)
            if (iWidth && iHeight) ; Avoid division by zero if ControlGetPos fails
            {
                if (iWidth / iHeight > oWidth / oHeight)
                    oHeight := width * iHeight / iWidth
                Else
                    oWidth := height * iWidth / iHeight

                ; Move/Resize the picture after calculating aspect ratio
            GuiControl, layoutLayer:Move, layoutPicture, % "x"width/2-oWidth/2 "y"height-oHeight "w"oWidth "h"oHeight
            } else {
                 GuiControl, layoutLayer:Move, layoutPicture, "x0 y0 w" width " h" height ; Fallback size
            }

        } else {
            ; Maybe add a placeholder or hide the picture control if image doesn't exist
            Gui, layoutLayer:Add, Picture, HwndmyPict vlayoutPicture w0 h0, ; Add hidden control
        }

        Gui, layoutLayer:Font, s%LayoutFontSize% cBlack, Verdana ; Consider making font/color configurable?
        Gui, layoutLayer:Add, Text, y0 x0 w%width% h%height% BackGroundTrans Center vlayoutNameID, %key%
    }
    Else{
        GuiControl, layoutLayer:Text, layoutNameID, %key%
        if( FileExist(image))
            GuiControl,layoutLayer:, layoutPicture, %image%
        ; if FileExist(image)
        ;     GuiControl, layoutLayer:, layoutPicture, % "x" width/2 - oWidth/2 " y" height - oHeight " w" oWidth " h" oHeight %image% ; Update image and position
        ; else
        ;      GuiControl, layoutLayer:, layoutPicture, *w0 *h0 ; Hide picture if image doesn't exist
    }

    ComputePosition(LayoutPosition.1, LayoutPosition.2, width, height, xPlacement, yPlacement)

    ; Only show if image exists? Original logic showed even without image, just no picture. Let's keep that.
    Gui, layoutLayer:Show, x%xPlacement% y%yPlacement% NoActivate AutoSize
    Winset, ExStyle, +0x20
    WinSet, Transparent, %LayoutTransparency%

    SetTimer, HideLayoutOSD, -%LayoutDuration%
    if (MomentaryTimerRunning) ; This logic seems related to momentary display, keep as is
        SetTimer, StopMomentaryDisplay, -%MomentaryLayoutDisplayDuration%

}

ComputePosition(ix, iy, width, height, ByRef x, ByRef y)
{
    ; This function is fine, handles strings like "center" and numbers correctly.
    if (ix = "center")
        x := A_ScreenWidth/2 - width/2
    else if (ix < 0)
        x := A_ScreenWidth - width + ix
    else
        x := ix

    if (iy = "center")
        y := A_ScreenHeight/2 - height/2
    else if (iy < 0)
        y := A_ScreenHeight - height + iy
    else
        y := iy
}

HideLayoutOSD()
{
    if (!NoDisplayTimeout)
        Gui, layoutLayer:Hide
    SetTimer, HideLayoutOSD, off
}

HideLayerNameOSD()
{
    if (!NoDisplayTimeout)
        Gui, indicatorLayer:Hide
    SetTimer, HideLayerNameOSD, off
}

; ==============================================================================
; --- Actions (Reload, Exit, Momentary Display) --- (Mostly unchanged)
; ==============================================================================
Reload()
{
    Reload ; Simple reload command
}

Exit(){
    ExitApp
}

MomentaryLayoutDisplay()
{
    if (!DisplayLayout) ; Only activate if layout display is currently off
    {
        DisplayLayout := 1 ; Temporarily enable layout display
        MomentaryTimerRunning := 1 ; Flag that we are in momentary mode
        ; Trigger an update if needed, or rely on the next InputMsg?
        ; Maybe force redraw based on *current* layer? Need current layer index.
        ; This part might need refinement depending on how current layer state is tracked.
        ; For now, it just enables the DisplayLayout flag. The next InputMsg will show the OSD.
        SetTimer, StopMomentaryDisplay, -%MomentaryLayoutDisplayDuration%
    }
    ; If DisplayLayout is already 1, this hotkey does nothing, which seems reasonable.
}

StopMomentaryDisplay()
{
    SetTimer, StopMomentaryDisplay, off
    if (MomentaryTimerRunning) ; Only act if we were the ones who turned it on
    {
        DisplayLayout := 0 ; Turn layout display back off
        HideLayoutOSD() ; Explicitly hide the OSD
    }
    MomentaryTimerRunning := 0 ; Reset the flag
}

; ==============================================================================
; --- Tray Menu Actions --- (Modified to use SaveConfigToJson)
; ==============================================================================

ChangeDisplayLayout()
{
    global DisplayLayout ; Ensure we modify the global variable
    if (DisplayLayout)
    {
        DisplayLayout := 0
        Menu, Tray, UnCheck, Show Layout
    }
    Else {
        DisplayLayout := 1
        Menu, Tray, Check, Show Layout
    }
    ;// JSON Change: Call save function instead of IniWrite
    SaveConfigToJson()
}

ChangeDisplayLayerName()
{
    global DisplayLayerName ; Ensure we modify the global variable
    if (DisplayLayerName)
    {
        DisplayLayerName := 0
        Menu, Tray, UnCheck, Show Layer Name
    }
    Else {
        DisplayLayerName := 1
        Menu, Tray, Check, Show Layer Name
    }
    ;// JSON Change: Call save function instead of IniWrite
    SaveConfigToJson()
}

ChangeNoDisplayTimeout(){
    global NoDisplayTimeout ; Ensure we modify the global variable
    if (NoDisplayTimeout)
    {
        NoDisplayTimeout := 0
        Gui, indicatorLayer:Hide ; Hide OSDs when timeout is re-enabled
        Gui, layoutLayer:Hide
        Menu, Tray, UnCheck, No timeout
    }
    Else {
        NoDisplayTimeout := 1
        Menu, Tray, Check, No timeout
    }
    ;// JSON Change: Call save function instead of IniWrite
    SaveConfigToJson()
}

; ==============================================================================
; End of Script
; ==============================================================================