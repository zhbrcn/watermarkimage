$ = (sel) -> document.querySelector sel

inputItems = ['text', 'font', 'color', 'alpha', 'angle', 'space', 'size']
input = {}
valueDisplays =
    alpha: document.querySelector '#alpha-value'
    angle: document.querySelector '#angle-value'
    space: document.querySelector '#space-value'
    size: document.querySelector '#size-value'

image = $ '#image'
graph = $ '#graph'
refresh = $ '#refresh'
autoRefresh = $ '#auto-refresh'
file = null
canvas = null
textCtx = null
redraw = null

dataURItoBlob = (dataURI) ->
    binStr = atob (dataURI.split ',')[1]
    len = binStr.length
    arr = new Uint8Array len

    for i in [0..len - 1]
        arr[i] = binStr.charCodeAt i
    new Blob [arr], type: 'image/png'


generateFileName = ->
    pad = (n) -> if n < 10 then '0' + n else n

    d = new Date
    '' + d.getFullYear() + '-' + (pad d.getMonth() + 1) + '-' + (pad d.getDate()) + ' ' + \
        (pad d.getHours()) + (pad d.getMinutes()) + (pad d.getSeconds()) + '.png'


readFile = ->
    return if not file?

    fileReader = new FileReader

    fileReader.onload = ->
        img = new Image
        img.onload = ->
            canvas = document.createElement 'canvas'
            canvas.width = img.width
            canvas.height = img.height
            textCtx = null
            
            ctx = canvas.getContext '2d'
            ctx.drawImage img, 0, 0

            redraw = ->
                ctx.clearRect 0, 0, canvas.width, canvas.height
                ctx.drawImage img, 0, 0
            
            drawText()

            graph.innerHTML = ''
            graph.appendChild canvas

            canvas.addEventListener 'click', ->
                link = document.createElement 'a'
                link.download = generateFileName()
                imageData = canvas.toDataURL 'image/png'
                blob = dataURItoBlob imageData
                link.href = URL.createObjectURL blob
                graph.appendChild link

                setTimeout ->
                    link.click()
                    graph.removeChild link
                , 100
                


        img.src = fileReader.result

    fileReader.readAsDataURL file
    

makeStyle = ->
    match = input.color.value.match /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i

    'rgba(' + (parseInt match[1], 16) + ',' + (parseInt match[2], 16) + ',' \
         + (parseInt match[3], 16) + ',' + input.alpha.value + ')'


fontStacks =
    system: '-apple-system,"Helvetica Neue",Helvetica,Arial,"PingFang SC","Hiragino Sans GB","WenQuanYi Micro Hei",sans-serif'
    inter: '"Inter",-apple-system,"Helvetica Neue",Helvetica,Arial,"PingFang SC","Hiragino Sans GB","WenQuanYi Micro Hei",sans-serif'
    noto: '"Noto Sans SC","PingFang SC","Hiragino Sans GB","WenQuanYi Micro Hei",sans-serif'
    mono: '"SFMono-Regular",Menlo,Monaco,Consolas,"Liberation Mono","Courier New",monospace'


formatValue = (key, val) ->
    switch key
        when 'alpha' then Math.round(val * 100) + '%'
        when 'angle' then Math.round(val) + '°'
        when 'space' then val.toFixed(1) + 'x'
        when 'size' then val.toFixed(2) + 'x'
        else val


updateValue = (key) ->
    display = valueDisplays[key]
    return unless display?

    val = parseFloat input[key].value
    display.textContent = formatValue key, val


drawText = ->
    return if not canvas?
    textSize = input.size.value * Math.max 15, (Math.min canvas.width, canvas.height) / 25
    
    if textCtx?
        redraw()
    else
        textCtx = canvas.getContext '2d'

    textCtx.save()
    textCtx.translate(canvas.width / 2, canvas.height / 2)
    textCtx.rotate (input.angle.value) * Math.PI / 180

    textCtx.fillStyle = makeStyle()
    fontName = fontStacks[input.font.value] or fontStacks.system
    textCtx.font = 'bold ' + textSize + 'px ' + fontName
    
    width = (textCtx.measureText input.text.value).width
    step = Math.sqrt (Math.pow canvas.width, 2) + (Math.pow canvas.height, 2)
    margin = (textCtx.measureText '啊').width

    x = Math.ceil step / (width + margin)
    y = Math.ceil (step / (input.space.value * textSize)) / 2

    for i in [-x..x]
        for j in [-y..y]
            textCtx.fillText input.text.value, (width + margin) * i, input.space.value * textSize * j
    
    textCtx.restore()
    return


image.addEventListener 'change', ->
    file = @files[0]

    return alert '仅支持 png, jpg, gif 图片格式' if file.type not in ['image/png', 'image/jpeg', 'image/gif']
    readFile()


autoRefresh.addEventListener 'change', ->
    if @checked
        refresh.setAttribute 'disabled', 'disabled'
    else
        refresh.removeAttribute 'disabled'

inputItems.forEach (item) ->
    el = $ '#' + item
    input[item] = el

    el.addEventListener 'input', ->
        updateValue item
        drawText() if autoRefresh.checked

refresh.addEventListener 'click', drawText

inputItems.forEach (item) -> updateValue item

