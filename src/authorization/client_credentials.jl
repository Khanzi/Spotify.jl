"""
    authorize()

Get and store client credentials. Any other credentials will be dropped.
"""
function authorize()
    @info "Retrieving client credentials, which typically lasts 1 hour."
    SPOTCRED[] = get_spotify_credentials()
    if string(SPOTCRED[]) != string(SpotifyCredentials())
        @info "Expires at $(SPOTCRED[].expires_at). Access `spotcred()`, refresh with `refresh_spotify_credentials()`."
    else
        @info "When configured, `refresh_spotify_credentials()`."
    end
end
function refresh_spotify_credentials()
    SPOTCRED[] = get_spotify_credentials()
    if string(SPOTCRED[]) != string(SpotifyCredentials())
        @info "Expires at $(SPOTCRED[].expires_at)."
    else
        @info "When configured, `refresh_spotify_credentials()`."
    end
end

function get_spotify_credentials()
    c = get_init_file_spotify_credentials()
    if string(c) == string(SpotifyCredentials())
        return c
    end
    j = get_authorization_token(c)
    if isnothing(j)
        return SpotifyCredentials()
    end
    c.access_token = j.access_token
    c.token_type = j.token_type
    c.expires_at = string(Dates.now() + Dates.Second(j.expires_in))
    c
end



function get_authorization_token(sc_tokenless::SpotifyCredentials)
    refreshtoken = sc_tokenless.encoded_credentials
    headers = ["Authorization" => "Basic $refreshtoken",
              "Accept" => "*/*",
              "Content-Type" => "application/x-www-form-urlencoded"]
    body = "grant_type=client_credentials"
    resp = HTTP.Messages.Response()
    try
        resp = HTTP.post(AUTH_URL, headers, body)
    catch e
        request = "HTTP.post call: AUTH_URL = $AUTH_URL\n  headers = $headers \n  body = $body"
        @error request
        @error e
        return nothing
    end
    response_body = resp.body |> String
    response_body |> JSON3.read
end

function get_init_file_spotify_credentials()
    id, secret, redirect = get_id_secret_redirect()
    if id == NOT_ACTUAL || secret == NOT_ACTUAL 
        @warn "User needs to configure $(_get_ini_fnam())"
        SpotifyCredentials()
    else
        enc_cred = base64encode(id * ":" * secret)
        c = SpotifyCredentials(client_id = id, client_secret =secret, encoded_credentials = enc_cred)
        c.redirect = redirect
        c
    end
end



"Get id and secret as 32-byte string, no encryption"
function get_id_secret_redirect()
    container = read(Inifile(), _get_ini_fnam())
    id = get(container, "Spotify developer's credentials", "CLIENT_ID",  NOT_ACTUAL)
    secret = get(container, "Spotify developer's credentials", "CLIENT_SECRET",  NOT_ACTUAL)
    redirect = get(container, "Spotify developer's credentials", "REDIRECT_URI",  DEFAULT_REDIRECT_URI)
    id, secret, redirect
end
#=
function get_working_browser_cmd()
    container = read(Inifile(), _get_ini_fnam())
    cmds = get(container, "Working browser command (auto filled in)", "CMD",  "")
    @cmd cmds
end
=#
#=
function set_working_browser_cmd(cmd)
    container = read(Inifile(), _get_ini_fnam())
    set(container, "Working browser command (auto filled in)", "CMD",  string(cmd))
end
=#
function get_user_name()
    container = read(Inifile(), _get_ini_fnam())
    get(container, "Spotify user id", "user_name",  "")
end

"Get an existing, readable ini file name, create it if necessary"
function _get_ini_fnam()
    fna = joinpath(homedir(), "spotify_credentials.ini")
    if !isfile(fna)
        open(fna, "w+") do io
            _prepare_init_file_with_instructions(io)
        end
        if Sys.iswindows()
            run(`cmd /c $fna`; wait = false)
        end
        println("Instructions in $fna")
    end
    fna
end

function _prepare_init_file_with_instructions(io)
    conta = Inifile()
    set(conta, "User procedure:", "1: How to get the CLIENT_ID", "Developer.spotify.com -> Dashboard -> log in -> Create an app -> Fill out name and purpose -> Copy to the field below.")
    set(conta, "User procedure:", "2: How to get CLIENT_SECRET", "When you have client id, press 'Show client secret' -> Copy to below. No need for quotation marks.")
    set(conta, "User procedure:", "3: How to give REDIRECT_URL", "Still in the app dashboard:
    'Edit settings' -> Redirect uris -> http://127.0.0.1:8080 -> Save changes")
    set(conta, "Spotify developer's credentials", "CLIENT_ID", NOT_ACTUAL)
    set(conta, "Spotify developer's credentials", "CLIENT_SECRET", NOT_ACTUAL)
    set(conta, "Spotify developer's credentials", "REDIRECT_URI", "http://127.0.0.1:8080")
    set(conta, "Spotify user id", "user_name", "Slartibartfast")
    write(io, conta)
end


client_credentials_still_valid() = now() < parse(DateTime, spotcred().expires_at)


