$ = (sel) -> document.querySelector sel

inputItems = ['text', 'font', 'color', 'alpha', 'angle', 'space', 'size']
input = {}
valueDisplays =
    alpha: document.querySelector '#alpha-value'
    angle: document.querySelector '#angle-value'
    space: document.querySelector '#space-value'
    size: document.querySelector '#size-value'

imageInput = $ '#image'
graph = $ '#graph'
refresh = $ '#refresh'
autoRefresh = $ '#auto-refresh'
clearAll = $ '#clear-all'
downloadZip = $ '#download-zip'
files = []
canvases = []

makeId = -> Math.random().toString(36).slice(2, 10)

baseName = (name) -> (name?.replace(/(\.[^.]+)?$/, '') or 'watermark')

dataURItoBlob = (dataURI) ->
    binStr = atob (dataURI.split ',')[1]
    len = binStr.length
    arr = new Uint8Array len

    for i in [0..len - 1]
        arr[i] = binStr.charCodeAt i
    new Blob [arr], type: 'image/png'


updateActions = ->
    hasFiles = files?.length > 0
    hasCanvas = canvases?.length > 0
    clearAll?.toggleAttribute 'disabled', not hasFiles
    downloadZip?.toggleAttribute 'disabled', (not hasCanvas) or (not window.JSZip?)


downloadCanvas = (canvas, name) ->
    link = document.createElement 'a'
    link.download = baseName(name) + '-marked.png'
    imageData = canvas.toDataURL 'image/png'
    blob = dataURItoBlob imageData
    link.href = URL.createObjectURL blob
    graph.appendChild link

    setTimeout ->
        link.click()
        graph.removeChild link
    , 60


removeEntry = (id) ->
    files = files.filter (item) -> item.id isnt id
    readFiles()


readFiles = ->
    graph.innerHTML = ''
    canvases = []
    return updateActions() if not files?.length

    files.forEach (entry) ->
        { file, id, name } = entry
        card = document.createElement 'div'
        card.className = 'preview-card'

        delBtn = document.createElement 'button'
        delBtn.className = 'delete-btn'
        delBtn.textContent = '删除'
        delBtn.addEventListener 'click', (e) ->
            e.stopPropagation()
            removeEntry id

        canvas = document.createElement 'canvas'

        card.appendChild delBtn
        card.appendChild canvas
        graph.appendChild card

        fileReader = new FileReader

        fileReader.onload = ->
            img = new Image
            img.onload = ->
                canvas.width = img.width
                canvas.height = img.height

                ctx = canvas.getContext '2d'
                ctx.drawImage img, 0, 0

                canvases.push { canvas, ctx, img, name, id }

                canvas.addEventListener 'click', -> downloadCanvas canvas, name
                drawText()
                updateActions()

            img.src = fileReader.result

        fileReader.readAsDataURL file

    updateActions()
    

makeStyle = ->
    match = input.color.value?.match /^#?([a-f\d]{2})([a-f\d]{2})([a-f\d]{2})$/i

    return 'rgba(29,155,240,' + input.alpha.value + ')' unless match?

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
    return unless canvases.length

    canvases.forEach ({ canvas, ctx, img }) ->
        textSize = input.size.value * Math.max 15, (Math.min canvas.width, canvas.height) / 25

        ctx.clearRect 0, 0, canvas.width, canvas.height
        ctx.drawImage img, 0, 0

        ctx.save()
        ctx.translate(canvas.width / 2, canvas.height / 2)
        ctx.rotate (input.angle.value) * Math.PI / 180

        ctx.fillStyle = makeStyle()
        fontName = fontStacks[input.font.value] or fontStacks.system
        ctx.font = 'bold ' + textSize + 'px ' + fontName

        text = input.text.value or '内部水印'
        width = (ctx.measureText text).width
        step = Math.sqrt (Math.pow canvas.width, 2) + (Math.pow canvas.height, 2)
        margin = (ctx.measureText '啊').width

        x = Math.ceil step / (width + margin)
        y = Math.ceil (step / (input.space.value * textSize)) / 2

        for i in [-x..x]
            for j in [-y..y]
                ctx.fillText text, (width + margin) * i, input.space.value * textSize * j

        ctx.restore()
    return


clearAll?.addEventListener 'click', ->
    files = []
    canvases = []
    graph.innerHTML = ''
    imageInput.value = ''
    updateActions()


downloadZip?.addEventListener 'click', ->
    return unless window.JSZip? and canvases.length

    zip = new JSZip()

    tasks = canvases.map ({ canvas, name }) ->
        new Promise (resolve, reject) ->
            canvas.toBlob (blob) ->
                return reject new Error('生成失败') unless blob?
                zip.file baseName(name) + '-marked.png', blob
                resolve()

    Promise.all(tasks)
        .then -> zip.generateAsync type: 'blob'
        .then (content) ->
            link = document.createElement 'a'
            link.href = URL.createObjectURL content
            link.download = 'watermarks.zip'
            document.body.appendChild link
            setTimeout ->
                link.click()
                document.body.removeChild link
            , 60
        .catch (err) -> console.error err


imageInput.addEventListener 'change', ->
    selected = Array.from @files or []
    validTypes = ['image/png', 'image/jpeg', 'image/gif']
    invalid = selected.filter (item) -> item.type not in validTypes
    additions = selected.filter (item) -> item.type in validTypes
    files = files.concat additions.map (file) ->
        file: file
        id: makeId()
        name: file.name

    alert '已忽略非 png/jpg/gif 的文件' if invalid.length
    return alert '请选择 png / jpg / gif 图片' unless files.length
    imageInput.value = ''
    readFiles()


autoRefresh.addEventListener 'change', ->
    if @checked
        refresh.setAttribute 'disabled', 'disabled'
    else
        refresh.removeAttribute 'disabled'

autoRefresh.addEventListener 'change', ->
    if @checked
        refresh.setAttribute 'disabled', 'disabled'
    else
        refresh.removeAttribute 'disabled'

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

