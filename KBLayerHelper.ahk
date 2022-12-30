#NoEnv
#SingleInstance, Force

script_title	:= "KBLayerHelper"
script_version	:= "12/27/2022"
script_author	:= "Raph.Coder"
script_ini		:= A_ScriptDir "\" script_title ".ini"



SetBatchLines, -1
SetWorkingDir, %A_ScriptDir%



global VendorId, ProductId
global DisplayLayout, LayoutSize, LayoutPosition, LayoutFontSize, LayoutDuration
global DisplayLayerName, LayerNameSize, LayerNamePosition, LayerNameFontSize, LayerNameDuration
global NoDisplayTimeout, LockHotKey, LayerArray


; Ini file read
ReadIniFile()


Hotkey, %LockHotKey%, ChangeNoDisplayTimeout, on



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
    Menu Tray, Check, No timeout


;Set up the constants
AHKHID_UseConstants()
usagePage := 65329
usage := 116

Gui, mainGUI:New, +LastFound +AlwaysOnTop -Border -SysMenu -Caption +ToolWindow
GuiHandle := WinExist()

;Intercept WM_INPUT
OnMessage(0x00FF, "InputMsg")

AHKHID_Register(usagePage, usage, GUIHANDLE, RIDEV_INPUTSINK)

Gui, mainGUI:Show
; Set tray icon of layer 0
SetTrayIcon(LayerArray[1].ico)
Return


ReadIniFile()
{
        local tmpLayer, curArray, curObj
    IniRead, VendorId, %script_ini%, Device, VendorId ,0x414B
    IniRead, ProductId, %script_ini%, Device, ProductId ,0x0001

    IniRead, NoDisplayTimeout, %script_ini%, General, NoDisplayTimeout ,0
    IniRead, LockHotKey, %script_ini%, General, LockHotKey ,!NumLock


    IniRead, DisplayLayout, %script_ini%, Layout, DisplayLayout ,1
    IniRead, inipos, %script_ini%, Layout, Position , center,-50
    LayoutPosition := StrSplit(inipos, ",", " `t")
    IniRead, inisize, %script_ini%, Layout, Size , 300,200
    LayoutSize := StrSplit(inisize, ",", " `t")
    IniRead, LayoutFontSize, %script_ini%, Layout, FontSize , 20


    IniRead, LayoutDuration, %script_ini%, Layout, Duration ,1000

    IniRead, DisplayLayerName, %script_ini%, LayerName, DisplayLayerName ,1
    IniRead, inipos, %script_ini%, LayerName, Position , center,-50
    LayerNamePosition := StrSplit(inipos, ",", " `t")
    IniRead, inisize, %script_ini%, LayerName, Size , 200,50
    LayerNameSize := StrSplit(inisize, ",", " `t")
    IniRead, LayerNameFontSize, %script_ini%, LayerName, FontSize , 20
    IniRead, LayerNameDuration, %script_ini%, LayerName, Duration ,1000

    LayerArray := [{}]
    Loop 16
    {
        idx := A_Index - 1
        IniRead tmpLayer, %script_ini%, Layers, Layer%idx%, Layer %idx%,./icons/ico/Number-%idx%.ico,./png/Layer-%idx%.png

        curArray := StrSplit(tmpLayer , ",")
        curArray[1] := Trim(curArray[1]) ? Trim(curArray[1]) : "Layer " Format("{:01}", idx)
        curArray[2] := Trim(curArray[2]) ? Trim(curArray[2]) : "./icons/ico/Number-" Format("{:01}", idx) ".ico"
        curArray[3] := Trim(curArray[3]) ? Trim(curArray[3]) : "./png/Layer-" Format("{:01}", idx) ".png"

        LayerArray[A_Index] := {label:curArray[1], ico:curArray[2], image:curArray[3]}

    }
}

InputMsg(wParam, lParam) {
    Local r, H
    Local iVendorID, iProductID, data
    Critical

    r := AHKHID_GetInputInfo(lParam, II_DEVTYPE)

    If(r = RIM_TYPEHID){
        h := AHKHID_GetInputInfo(lParam, II_DEVHANDLE)
        r := AHKHID_GetInputData(lParam, uData)
        offset := 0x1

        iVendorID := AHKHID_GetDevInfo(h, DI_HID_VENDORID,     True)
        iProductID :=  AHKHID_GetDevInfo(h, DI_HID_PRODUCTID,    True)
        If(iVendorID == VendorId and iProductID == ProductId)
        {
            mystring := StrGet(&uData + offset, "UTF-8")
            If(SubStr(mystring, 1, 5) == "Layer"){
                idx := SubStr(myString, 6)

                SetTrayIcon(LayerArray[idx+1].ico)

                If (DisplayLayout)
                    ShowLayoutOSD(LayerArray[idx + 1].label, LayerArray[idx + 1].image)
                If (DisplayLayerName)
                    ShowLayerNameOSD(LayerArray[idx + 1].label)

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
    WinSet, Transparent, 128


    SetTimer, HideLayerNameOSD, -%LayerNameDuration%


}

 ShowLayoutOSD(key, image){
    static layoutNameID
    static layoutPicture
    bgTopPadding = 40
    bgWidthPadding = 50

    width := LayoutSize.1
    height := LayoutSize.2

    padding := 20



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

    Gui, Show, x%xPlacement% y%yPlacement%  NoActivate AutoSize
    Winset, ExStyle, +0x20
    WinSet, Transparent, 128
    SetTimer, HideLayoutOSD, -%LayoutDuration%

}


ComputePosition(ix, iy, width, height,ByRef  x, ByRef y)
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


;---------------------------------------------------------------------
; Reload
;---------------------------------------------------------------------
Reload:
	Reload
Return

;---------------------------------------------------------------------
; Exit
;---------------------------------------------------------------------
Exit:

	ExitApp
Return



ChangeDisplayLayout:

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
Return

ChangeDisplayLayerName:
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
Return

ChangeNoDisplayTimeout:
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

Return
