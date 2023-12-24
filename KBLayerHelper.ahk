#NoEnv
#SingleInstance, Force

script_title	:= "KBLayerHelper"
script_version	:= "17/01/2023"
script_author	:= "Raph.Coder"
global script_ini		:= A_ScriptDir "\" script_title ".ini"



SetBatchLines, -1
SetWorkingDir, %A_ScriptDir%



global VendorId, ProductId
global DisplayLayout, LayoutSize, LayoutPosition, LayoutFontSize, LayoutDuration, LayoutTransparency
global DisplayLayerName, LayerNameSize, LayerNamePosition, LayerNameFontSize, LayerNameDuration, LayerNameTransparency
global NoDisplayTimeout, LockHotKey, LayerArray, LayoutDisplayHotKey
global MomentaryLayoutDisplayHotKey, MomentaryLayoutDisplayDuration, MomentaryTimerRunning

MomentaryTimerRunning := 0

; Ini file read
ReadIniFile()

; Set hotkey to disable timeout
Hotkey, %LockHotKey%, ChangeNoDisplayTimeout, on
Hotkey, %LayoutDisplayHotKey%, ChangeDisplayLayout, on
Hotkey, %MomentaryLayoutDisplayHotKey%, MomentaryLayoutDisplay, on

; Construct tray icon menu
Menu Tray, NoStandard
Menu Tray, Add,  Show Layout,  ChangeDisplayLayout
Menu Tray, Add,  Show Layer Name,  ChangeDisplayLayerName
Menu Tray, Add,  No timeout,  ChangeNoDisplayTimeout

Menu Tray, Add ; seperator
Menu Tray, Add, Reload %script_title%, Reload
Menu Tray, Add, Exit %script_title%, Exit


if DisplayLayout
    Menu Tray, Check, Show Layout

if DisplayLayerName
    Menu Tray, Check, Show Layer Name

if NoDisplayTimeout
    Menu Tray, Check, No timeoutr


;Set up the constants
AHKHID_UseConstants()
usagePage := 65329
usage := 116

Gui, mainGUI:New, +LastFound +AlwaysOnTop -Border -SysMenu -Caption +ToolWindow
GuiHandle := WinExist()

;Intercept WM_INPUT
OnMessage(0x00FF, "InputMsg",1)

AHKHID_Register(usagePage, usage, GUIHANDLE, RIDEV_INPUTSINK)

Gui, mainGUI:Show
; Set tray icon of layer 0
SetTrayIcon(LayerArray[0].ico)
Return


ReadIniFile()
{
        local tmpLayer, curArray, curObj
    IniRead, VendorId, %script_ini%, Device, VendorId ,0x414B
    IniRead, ProductId, %script_ini%, Device, ProductId ,0x0001

    IniRead, NoDisplayTimeout, %script_ini%, General, NoDisplayTimeout ,0
    IniRead, LockHotKey, %script_ini%, General, LockHotKey ,!NumLock
    IniRead, LayoutDisplayHotKey, %script_ini%, General, LayoutDisplayHotKey ,+^!#d
    IniRead, MomentaryLayoutDisplayHotKey, %script_ini%, General, MomentaryLayoutDisplayHotKey ,+^!#f
    IniRead, MomentaryLayoutDisplayDuration, %script_ini%, General, MomentaryLayoutDisplayDuration, 1000


    IniRead, DisplayLayout, %script_ini%, Layout, DisplayLayout ,1
    IniRead, inipos, %script_ini%, Layout, Position , center,-50
    LayoutPosition := StrSplit(inipos, ",", " `t")
    IniRead, inisize, %script_ini%, Layout, Size , 300,200
    LayoutSize := StrSplit(inisize, ",", " `t")
    IniRead, LayoutFontSize, %script_ini%, Layout, FontSize , 20
    IniRead, LayoutTransparency, %script_ini%, Layout, Transparency , 128

    IniRead, LayoutDuration, %script_ini%, Layout, Duration ,1000

    IniRead, DisplayLayerName, %script_ini%, LayerName, DisplayLayerName ,1
    IniRead, inipos, %script_ini%, LayerName, Position , center,-50
    LayerNamePosition := StrSplit(inipos, ",", " `t")
    IniRead, inisize, %script_ini%, LayerName, Size , 200,50
    LayerNameSize := StrSplit(inisize, ",", " `t")
    IniRead, LayerNameFontSize, %script_ini%, LayerName, FontSize , 20
    IniRead, LayerNameDuration, %script_ini%, LayerName, Duration ,1000
    IniRead, LayerNameTransparency, %script_ini%, LayerName, Transparency ,128

    LayerArray := [{}]

    ; Read all Layers section
    IniRead, outputVarSection, %script_ini%, Layers

    For array_idx, layerLine in StrSplit(outputVarSection, "`n", " `t")
    {
        local idx, cur_LayerArray
        idx := array_idx - 1

        ; Remove the 'key='' in front of the line by looking for the first =
        ; Search for =
        pos := InStr(layerLine, "=")
        if pos > 0
        {
            layerLine := SubStr(layerLine, pos+1)

            ; Split line with ,

            cur_LayerArray := StrSplit(layerLine , ",", " `t")


            layerRef := Trim(cur_LayerArray[1]) ? Trim(cur_LayerArray[1]) : Format("{:01}", idx)
            ; Layer name
            cur_LayerArray[2] := Trim(cur_LayerArray[2]) ? Trim(cur_LayerArray[2]) : "Layer " layerRef
            ; Layer icon
            cur_LayerArray[3] := Trim(cur_LayerArray[3]) ? Trim(cur_LayerArray[3]) : "./icons/ico/Number-" layerRef ".ico"
            ; Layer image
            cur_LayerArray[4] := Trim(cur_LayerArray[4]) ? Trim(cur_LayerArray[4]) : "./png/Layer-" layerRef ".png"

            LayerArray[layerRef] := {label:cur_LayerArray[2], ico:cur_LayerArray[3], image:cur_LayerArray[4]}
        }

    }

}


InputMsg(wParam, lParam, msg) {
    Local r, H
    Local iVendorID, iProductID, data, mystring
    Critical


    r := AHKHID_GetInputInfo(lParam, II_DEVTYPE)

    If(r = RIM_TYPEHID){
        h := AHKHID_GetInputInfo(lParam, II_DEVHANDLE)
        r := AHKHID_GetInputData(lParam, uData)
        offset := 0x1


        iVendorID := AHKHID_GetDevInfo(h, DI_HID_VENDORID,     True)
        iProductID :=  AHKHID_GetDevInfo(h, DI_HID_PRODUCTID,    True)
        If(iVendorID == VendorId)
        ; If(iVendorID == VendorId and iProductID == ProductId)
        {
            orgString:= StrGet(&uData + offset, "UTF-8")
            mystring := Trim(StrGet(&uData + offset, "UTF-8"), OmitChars := "`t`n`r")
            Loop, Parse, mystring, `n, `r
            {
                foundPos := InStr(A_LoopField, "KBHLayer")
                If(foundPos>0){

                    idx := SubStr(A_LoopField, 8+foundPos)
                    SetTrayIcon(LayerArray[idx].ico)

                    If (DisplayLayout)
                        ShowLayoutOSD(LayerArray[idx].label, LayerArray[idx].image)
                    If (DisplayLayerName)
                        ShowLayerNameOSD(LayerArray[idx].label)

                }
            }
        }
    }
    return
}


SetTrayIcon(iconname){
    If FileExist(iconname)
        Menu, Tray, Icon, %iconname%
}

ShowLayerNameOSD(key){
    static layerNameTxtID, layerNamePictureID

    width := LayerNameSize.1
    height := LayerNameSize.2

    ComputePosition(LayerNamePosition.1, LayerNamePosition.2, width, height, xPlacement, yPlacement)


    if !WinExist("layerGUI")
    {
        Gui, indicatorLayer:New, +LastFound +AlwaysOnTop -Border -SysMenu +Owner -Caption +ToolWindow +E0x08000000, layerGUI
        Gui, indicatorLayer:Color, FF0000
        Gui, indicatorLayer:Margin, 0, 0

        ; Gui, indicatorLayer:Add, Picture, x0 y0 w%width% h%height% vlayerNamePictureID AltSubmit BackgroundTrans , ./png/LayerBox.png
        Gui, indicatorLayer:Font, s%LayerNameFontSize% cWhite, Verdana
        Gui, indicatorLayer:Add, Text, x0 y0 w%width% h%height% BackGroundTrans Center vlayerNameTxtID,%key%
    }
    else
    {
        GuiControl, indicatorLayer:Text, layerNameTxtID, %key%
    }


    Gui, indicatorLayer:Show, x%xPlacement% y%yPlacement% NoActivate  AutoSize
    Winset, ExStyle, +0x20
    ; WinSet, TransColor, FFFFFF 64
    WinSet, Transparent, %LayerNameTransparency%

    SetTimer, HideLayerNameOSD, -%LayerNameDuration%

}

 ShowLayoutOSD(key, image){
    static layoutNameID
    static layoutPicture

    width := LayoutSize.1
    height := LayoutSize.2

    If  !WinExist("layoutGUI")
    {
        Gui, layoutLayer:New, +LastFound +AlwaysOnTop -Border -SysMenu +Owner -Caption +ToolWindow +E0x08000000, layoutGUI
        Gui, Margin, 0, 0

        oWidth := width
        oHeight := height
        if( FileExist(image))
        {
            static picture

            Gui, Add, Picture, HwndmyPict vlayoutPicture  AltSubmit BackgroundTrans, %image%

            ControlGetPos,,,iWidth,iHeight,, ahk_id %myPict%

            if(iWidth / iHeight > oWidth/oHeight)
                oHeight := width*iHeight/iWidth
            Else
                oWidth := height*iWidth/iHeight


            GuiControl, layoutLayer:Move, layoutPicture, % "x"width/2-oWidth/2 "y"height-oHeight "w"oWidth "h"oHeight

        }



        Gui, Font, s%LayoutFontSize% cBlack, Verdana
        Gui, layoutLayer:Add, Text, y0 x0 w%width% h%height% BackGroundTrans Center vlayoutNameID, %key%
    }
    Else{
        ; OutputDebug, REUSE - %layoutNameID% - %layoutPicture%
        GuiControl, layoutLayer:Text, layoutNameID, %key%
        if( FileExist(image))
            GuiControl,layoutLayer:, layoutPicture, %image%

    }


    ComputePosition(LayoutPosition.1, LayoutPosition.2, width, height, xPlacement, yPlacement)

    if (FileExist(image)){
        Gui, Show, x%xPlacement% y%yPlacement%  NoActivate AutoSize
        Winset, ExStyle, +0x20
        WinSet, Transparent, %LayoutTransparency%

        SetTimer, HideLayoutOSD, -%LayoutDuration%
        if(MomentaryTimerRunning)
            SetTimer, StopMomentaryDisplay, -%MomentaryLayoutDisplayDuration%

    }
    Else
        HideLayoutOSD()

}

; Calculate OSD screen position
; if position >= 0 : from top/left of the screen
; if position < 0 : from bottom/right
; 'center' to center OSD on screen
ComputePosition(ix, iy, width, height, ByRef  x, ByRef y)
{
    if(ix = "center")
    {
        x := % A_ScreenWidth/2 - width/2
    }
    else{
        if(ix < 0)
            x := % A_ScreenWidth - width + ix
        else
            x := ix
    }

    if(iy = "center")
    {
        y := % A_ScreenHeight/2 - height/2
    }
    else{
        if(iy < 0)
            y := % A_ScreenHeight - height + iy
        else
            y := iy
    }

}

HideLayoutOSD()
{
    if( !NoDisplayTimeout)
        Gui, layoutLayer:Hide
    SetTimer, HideLayoutOSD, off
}


HideLayerNameOSD()
{

    if( !NoDisplayTimeout)
        Gui, indicatorLayer:Hide
    SetTimer, HideLayerNameOSD, off
}


; Reload the app
Reload()
{
	Reload
}

; Exit the app
Exit(){
	ExitApp
}

MomentaryLayoutDisplay()
{
    if(!DisplayLayout)
    {
        SetTimer, StopMomentaryDisplay, -%MomentaryLayoutDisplayDuration%
        DisplayLayout := 1
        MomentaryTimerRunning := 1
    }
}

StopMomentaryDisplay()
{
    SetTimer, StopMomentaryDisplay, off
    if(MomentaryTimerRunning)
        DisplayLayout := 0
    MomentaryTimerRunning := 0
}
; On tray menu action, change check mark and write .ini file
ChangeDisplayLayout()
{

    if(DisplayLayout)
    {
        DisplayLayout := 0
        Menu, Tray, UnCheck, Show Layout
    }
    Else{
        DisplayLayout := 1
        Menu, Tray, Check, Show Layout
    }
	IniWrite %DisplayLayout%, %script_ini%, Layout, DisplayLayout
}


; On tray menu action, change check mark and write .ini file
ChangeDisplayLayerName()
{
    if(DisplayLayerName)
    {
        DisplayLayerName := 0
        Menu, Tray, UnCheck, Show Layer Name
    }
    Else{
        DisplayLayerName := 1
        Menu, Tray, Check, Show Layer Name
    }
	IniWrite %DisplayLayerName%, %script_ini%, LayerName, DisplayLayerName
}

; On tray menu action, change check mark and write .ini file
ChangeNoDisplayTimeout(){
    if(NoDisplayTimeout)
    {
        NoDisplayTimeout := 0
        Gui, indicatorLayer:Hide
        Gui, layoutLayer:Hide
        Menu, Tray, UnCheck, No timeout
    }
    Else{
        NoDisplayTimeout := 1
        Menu, Tray, Check, No timeout
    }
	IniWrite %NoDisplayTimeout%, %script_ini%, General, NoDisplayTimeout
}

