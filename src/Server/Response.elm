module Server.Response exposing
    ( Response
    , json, plainText, temporaryRedirect, permanentRedirect
    , emptyBody, body, bytesBody, base64Body
    , render
    , map
    , withHeader, withHeaders, withStatusCode, withSetCookieHeader
    , toJson
    )

{-|


## Responses

@docs Response

There are two top-level response types:

1.  Server Responses
2.  Render Responses

A Server Response is a way to directly send a low-level server response, with no additional magic. You can set a String body,
a list of headers, the status code, etc. The Server Response helpers like `json` and `temporaryRedirect` are just helpers for
building up those low-level Server Responses.

Render Responses are a little more special in the way they are connected to your elm-pages app. They allow you to render
the current Route Module. To do that, you'll need to pass along the `data` for your Route Module.

You can use `withHeader` and `withStatusCode` to customize either type of Response (Server Responses or Render Responses).


## Server Responses

@docs json, plainText, temporaryRedirect, permanentRedirect


## Custom Responses

@docs emptyBody, body, bytesBody, base64Body


## Render Responses

@docs render

@docs map


## Amending Responses

@docs withHeader, withHeaders, withStatusCode, withSetCookieHeader


## Internals

@docs toJson

-}

import Base64
import Bytes exposing (Bytes)
import Json.Encode
import PageServerResponse exposing (PageServerResponse(..))
import Server.SetCookie as SetCookie exposing (SetCookie)


{-| -}
type alias Response data =
    PageServerResponse data


{-| -}
map : (data -> mappedData) -> Response data -> Response mappedData
map mapFn pageServerResponse =
    case pageServerResponse of
        RenderPage response data ->
            RenderPage response (mapFn data)

        ServerResponse serverResponse ->
            ServerResponse serverResponse


{-| -}
plainText : String -> Response data
plainText string =
    { statusCode = 200
    , headers = [ ( "Content-Type", "text/plain" ) ]
    , body = Just string
    , isBase64Encoded = False
    }
        |> ServerResponse


{-| -}
render : data -> Response data
render data =
    RenderPage
        { statusCode = 200, headers = [] }
        data


{-| -}
emptyBody : Response data
emptyBody =
    { statusCode = 200
    , headers = []
    , body = Nothing
    , isBase64Encoded = False
    }
        |> ServerResponse


{-| -}
body : String -> Response data
body body_ =
    { statusCode = 200
    , headers = []
    , body = Just body_
    , isBase64Encoded = False
    }
        |> ServerResponse


{-| -}
base64Body : String -> Response data
base64Body base64String =
    { statusCode = 200
    , headers = []
    , body = Just base64String
    , isBase64Encoded = True
    }
        |> ServerResponse


{-| -}
bytesBody : Bytes -> Response data
bytesBody bytes =
    { statusCode = 200
    , headers = []
    , body = bytes |> Base64.fromBytes
    , isBase64Encoded = True
    }
        |> ServerResponse


{-| -}
json : Json.Encode.Value -> Response data
json jsonValue =
    { statusCode = 200
    , headers =
        [ ( "Content-Type", "application/json" )
        ]
    , body =
        jsonValue
            |> Json.Encode.encode 0
            |> Just
    , isBase64Encoded = False
    }
        |> ServerResponse


{-| Build a 308 permanent redirect response.

Permanent redirects tell the browser that a resource has permanently moved. If you redirect because a user is not logged in,
then you **do not** want to use a permanent redirect because the page they are looking for hasn't changed, you are just
temporarily pointing them to a new page since they need to authenticate.

Permanent redirects are aggressively cached so be careful not to use them when you mean to use temporary redirects instead.

If you need to specifically rely on a 301 permanent redirect (see <https://stackoverflow.com/a/42138726> on the difference between 301 and 308),
use `customResponse` instead.

-}
permanentRedirect : String -> Response data
permanentRedirect url =
    { body = Nothing
    , statusCode = 308
    , headers =
        [ ( "Location", url )
        ]
    , isBase64Encoded = False
    }
        |> ServerResponse


{-| -}
temporaryRedirect : String -> Response data
temporaryRedirect url =
    { body = Nothing
    , statusCode = 302
    , headers =
        [ ( "Location", url )
        ]
    , isBase64Encoded = False
    }
        |> ServerResponse


{-| -}
withStatusCode : Int -> Response data -> Response data
withStatusCode statusCode serverResponse =
    case serverResponse of
        RenderPage response data ->
            RenderPage { response | statusCode = statusCode } data

        ServerResponse response ->
            ServerResponse { response | statusCode = statusCode }


{-| -}
withHeader : String -> String -> Response data -> Response data
withHeader name value serverResponse =
    case serverResponse of
        RenderPage response data ->
            RenderPage { response | headers = ( name, value ) :: response.headers } data

        ServerResponse response ->
            ServerResponse { response | headers = ( name, value ) :: response.headers }


{-| -}
withHeaders : List ( String, String ) -> Response data -> Response data
withHeaders headers serverResponse =
    case serverResponse of
        RenderPage response data ->
            RenderPage { response | headers = headers ++ response.headers } data

        ServerResponse response ->
            ServerResponse { response | headers = headers ++ response.headers }


{-| -}
withSetCookieHeader : SetCookie -> Response data -> Response data
withSetCookieHeader cookie response =
    response
        |> withHeader "Set-Cookie"
            (cookie
                |> SetCookie.toString
            )


{-| -}
toJson : Response Never -> Json.Encode.Value
toJson response =
    case response of
        RenderPage _ data ->
            never data

        ServerResponse serverResponse ->
            PageServerResponse.toJson serverResponse
