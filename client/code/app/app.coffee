# Client-side Code

# Bind to socket events
app=require '/app'
util=require '/util'
ss.server.on 'disconnect', ->
    util.message "服务器","连接已断开。"
ss.server.on 'reconnect', ->
    util.message "服务器","连接已恢复，请刷新页面。"
libban = require '/ban'
    

# 全体告知
ss.event.on 'grandalert', (msg)->
    util.message msg.title,msg.message
# 強制リロード
ss.event.on 'forcereload', ()->
    location.reload()

# This method is called automatically when the websocket connection is established. Do not rename/delete

# cached values
my_userid=null
application_config=null

exports.init = ->
    # 固定リンク
    $("a").live "click", (je)->
        t=je.currentTarget
        return if je.isDefaultPrevented()
        href = t.href
        unless t.classList.contains "mode-change-link"
            if application_config?.modes?
                curidx = -1
                hrefidx = -1
                modes = application_config.modes
                for mode, i in modes
                    if location.href.indexOf(mode.url) == 0
                        curidx = i
                    if href.indexOf(mode.url) == 0
                        hrefidx = i
                if hrefidx >= 0 && hrefidx != curidx
                    # hrefを書き換え
                    href = modes[curidx].url + href.slice(modes[hrefidx].url.length)
        if href != t.href
            t.href = href

        return if t.target=="_blank"
        je.preventDefault()


        app.showUrl href
        return
    # ヘルプアイコン
    $("i[data-helpicon]").live "click", (je)->
        t = je.currentTarget
        util.message "帮助", t.title

    # 自動ログイン
    if localStorage.userid && localStorage.password
        login localStorage.userid, localStorage.password,(result)->
            p = location.href
            if result
                p = location.href
                if location.pathname == "/" then p = "/my"
            else
                #p="/"
                # 無効
                localStorage.removeItem "userid"
                localStorage.removeItem "password"
            showUrl p
    else
        ss.rpc "user.hello", {}, (e)->
            if e.banid
                libban.saveBanData e.banid
            else if e.forgive
                libban.removeBanData()
            else
                checkBanData()

        showUrl location.href
    # ユーザーCSS指定
    cp=useColorProfile getCurrentColorProfile()

    # 履歴の移動
    window.addEventListener "popstate",((e)->
        # location.pathname
        showUrl location.pathname, util.searchHash(location.search), true
    ),false
    # application configを取得
    loadApplicationConfig()
  
exports.page=page=(templatename,params=null,pageobj,startparam)->
    cdom=$("#content").get(0)
    jQuery.data(cdom,"end")?()
    jQuery.removeData cdom,"end"
    $("#content").empty()
    $(JT["#{templatename}"](params)).appendTo("#content")
    if pageobj
        pageobj.start(startparam)
        jQuery.data cdom, "end", pageobj.end
# マニュアルを表示
manualpage=(pagename)->
    resp=(tmp)->
        cdom=$("#content").get(0)
        jQuery.data(cdom,"end")?()
        jQuery.removeData cdom,"end"
        $("#content").empty()
        
        $(tmp).appendTo("#content")
        pageobj=Index.manual
        if pageobj
            pageobj.start()
            jQuery.data cdom, "end", pageobj.end

    if sessionStorage["manual_#{pagename}"]
        # すでに取得済み
        resp sessionStorage["manual_#{pagename}"]
        return
    xhr=new XMLHttpRequest()
    xhr.open "GET","/rawmanual/#{pagename}"
    xhr.responseType="text"
    xhr.onload=(e)->
        #if e.status==200
        sessionStorage["manual_#{pagename}"]=xhr.response
        resp xhr.response

    xhr.send()



exports.showUrl=showUrl=(url,query={},nohistory=false)->
    try
        u = new URL url
        if u.origin == location.origin
            url = u.pathname
            # urlSearchParams
            query = util.searchHash u.search
        else
            location.href = url
            return
    catch e
        # fallback
        if result=url.match /(https?:\/\/.+?)(\/.+)$/
            if result[1]=="#{location.protocol}//#{location.host}" #location.origin
                # no query support!
                body = result[2]
                # search部分を探す
                idx = body.indexOf '?'
                if idx >= 0
                    url = body.slice 0, idx
                    idx2 = body.indexOf '#', idx
                    query = url.searchHash url.slice(idx, idx2)
                else
                    idx2 = body.indexOf '#'
                    if idx2 >= 0
                        url = body.slice 0, idx2
                    else
                        url = body
            else
                location.href=url
                return
    
    switch url
        when "/my"
            # プロフィールとか
            pf = ()=>
                ss.rpc "user.myProfile", (user)->
                    unless user?
                        # ログインしていない
                        showUrl "/", {}, nohistory
                        return
                    user[x]?="" for x in ["userid","name","comment"]
                    page "user-profile",user,Index.user.profile,user

            if query.token?.match?(/^\w{128}$/) && query.timestamp?.match?(/^\d{13}$/)
                ss.rpc "user.confirmMail", {
                    token: query.token
                    timestamp: query.timestamp
                }, (result)->
                    if result?.error?
                        Index.util.message "错误",result.error
                        return
                    if result?.info?
                        Index.util.message "通知",result.info
                    if result?.reset
                        showUrl "/", {}, nohistory
                    else
                        pf()
            else
                pf()
        when "/my/log"
            page "user-mylog", {
                loggedin: my_userid?
            }, Index.user.mylog, null
        when "/reset"
            # 重置密码
            page "reset",null,Index.reset, null
        when "/rooms"
            # 部屋一覧
            page "game-rooms", {
                my: false
            }, Index.game.rooms, {
                page: Number query.page || 0
            }
        when "/rooms/old"
            # 古い部屋
            page "game-rooms", {
                my: false
            }, Index.game.rooms, {
                mode: "old"
                page: Number query.page || 0
            }
        when "/rooms/log"
            # 終わった部屋
            page "game-rooms", {
                my: false
            },Index.game.rooms, {
                mode: "log"
                page: Number query.page || 0
            }
        when "/rooms/my"
            # ぼくの部屋
            page "game-rooms", {
                my: true
            }, Index.game.rooms, {
                mode: "my"
                page: Number query.page || 0
            }
        when "/newroom"
            # 新しい部屋
            page "game-newroom",null,Index.game.newroom,null
        when "/lobby"
            # ロビー
            page "lobby",null,Index.lobby,null
        when "/manual"
            # マニュアルトップ
            #page "manual-top",null,Index.manual,null
            manualpage "top"
        when "/admin"
            # 管理者ページ
            page "admin",null,Index.admin,null
        when "/logout"
            # ログアウト
            ss.rpc "user.logout", ->
                my_userid=null
                localStorage.removeItem "userid"
                localStorage.removeItem "password"
                $("#username").empty()
                $("#login").show()
                $("#logout").hide()
                showUrl "/", {}, nohistory
        when "/logs"
            # ログ検索
            page "logs",null,Index.logs,null
        else
            if result=url.match /^\/room\/-?(\d+)$/
                # 房间
                page "game-game",null,Index.game.game,parseInt result[1]
                $("#content").css "max-width","95%"
            else if result=url.match /^\/user\/(\w+|替身君|%E6%9B%BF%E8%BA%AB%E5%90%9B)$/
                userid = result[1]
                if userid == "%E6%9B%BF%E8%BA%AB%E5%90%9B"
                    userid = "替身君"
                # ユーザー
                page "user-view",null,Index.user.view,userid
            else if result=url.match /^\/manual\/job\/(\w+)$/
                # ジョブ情報
                win=util.blankWindow {
                    title: "职业说明"
                }
                $(JT["jobs-#{result[1]}"]()).appendTo win
                return
            else if result=url.match /^\/manual\/casting\/(.*)$/
                # キャスティング情報
                if result[1]=="index" || result[1]==""
                    # 一览
                    page "pages-castlist",null,Index.pages.castlist
                else
                    page "pages-casting",null,Index.pages.casting,result[1]
            else if result=url.match /^\/manual\/([-\w]+)$/
                #page "manual-#{result[1]}",null,Index.manual,null
                manualpage result[1]
            else if result=url.match /^\/backdoor\/(\w+)$/
                ss.rpc "app.backdoor", result[1],(url)->
                    if url?
                        location.replace url
            else
                page "top",null,Index.top,null
    unless nohistory
        pushState url, query
    unless url.match /^\/room\/-?(\d+)$/
        $("#content").removeAttr "style"
exports.pushState=pushState=(url, query)->
    history.pushState null, null, "#{url}#{util.hashSearch query}"
                    
                    
exports.refresh=->showUrl location.pathname, util.searchHash(location.search), true

exports.login=login=(uid,ups,cb)->
    ss.rpc "user.login", {userid:uid,password:ups},(result)->
        processLoginResult uid, result, cb
exports.processLoginResult = processLoginResult = (uid, result, cb)->
    if result.banid
        libban.saveBanData result.banid
    else if result.forgive
        libban.removeBanData()
    if result.login
        # OK
        my_userid=uid
        $("#username").text uid
        $("#login").hide()
        $("#logout").show()
        if result.lastNews && localStorage.latestNews
            # 最終ニュースを比較
            last=new Date result.lastNews
            latest=new Date localStorage.latestNews
            if last.getTime() > latest.getTime()
                # 新着ニュースあり
                # お知らせを入れる
                notice=document.createElement "div"
                notice.classList.add "notice"
                notice.id="newNewsNotice"
                notice.textContent="有新的通知，请前往个人页面查看。"
                $("#content").before notice

        cb? true
    else
        cb? false
    unless result.banid
        # banではない?
        checkBanData()
exports.userid=->my_userid
exports.setUserid=(id)->my_userid=id

# カラー设定を読み込む
exports.getCurrentColorProfile=getCurrentColorProfile=->
    p=localStorage.colorProfile || "{}"
    obj=null
    try
        obj=JSON.parse p

    catch e
        # default setting
        obj={}
    unless obj.day?
        obj.day=
            bg:"#ffd953"
            color:"#000000"
    unless obj.night?
        obj.night=
            bg:"#000044"
            color:"#ffffff"
    unless obj.heaven?
        obj.heaven=
            bg:"#fffff0"
            color:"#000000"
    return obj
# 保存する
exports.setCurrentColorProfile=(cp)->
    localStorage.colorProfile=JSON.stringify cp
# カラー设定反映
exports.useColorProfile=useColorProfile=(cp)->
    st=$("#profilesheet").get 0
    if st?
        sheet=st.sheet
        # 设定されているものを利用
        while sheet.cssRules.length>0
            sheet.deleteRule 0
            
    else
        # 新規に作る
        st=$("<style id='profilesheet'>").appendTo(document.head).get 0
        sheet=st.sheet
    # 规则を定義
    sheet.insertRule """
body.day, #logs .day {
    background-color: #{cp.day.bg};
    color: #{cp.day.color};
}""",0
    sheet.insertRule """
body.night, #logs .werewolf, #logs .monologue {
    background-color: #{cp.night.bg};
    color: #{cp.night.color};
}""",1
    sheet.insertRule """
body.night:not(.heaven) a, #logs .werewolf a, #logs .monologue a{
    color: #{cp.night.color};
}""",2
    sheet.insertRule """
body.heaven, #logs .heaven, #logs .prepare {
    background-color: #{cp.heaven.bg};
    color: #{cp.heaven.color};
}""",3
    return

exports.getApplicationConfig = ()-> application_config

loadApplicationConfig = ()->
    ss.rpc "app.applicationconfig", (conf)->
        application_config = conf
        # HTTP/HTTPS切り替えのための
        # ツールバーを設定
        modes = application_config.modes
        if modes?
            for m in modes
                if location.href.indexOf(m.url) != 0
                    span = document.createElement "span"
                    span.classList.add "tool-button"
                    if m.icon
                        icon = document.createElement "i"
                        icon.classList.add "fa"
                        icon.classList.add "fa-#{m.icon}"
                        span.appendChild icon
                    a = document.createElement "a"
                    a.href = m.url
                    a.classList.add "mode-change-link"
                    a.appendChild(document.createTextNode "前往 #{m.name}")
                    span.appendChild a
                    $("#toolbar").append span
                ###
                else
                    span.classList.add "tool-disabled"
                    span.appendChild(document.createTextNode "現在#{m.name}です")
                ###

checkBanData = ()->
    libban.loadBanData (data)->
        if data?
            console.log "bay", data
            ss.rpc "user.requestban", data, (result)->
                if result.banid
                    libban.saveBanData result.banid
                else if result.forgive
                    libban.removeBanData()
