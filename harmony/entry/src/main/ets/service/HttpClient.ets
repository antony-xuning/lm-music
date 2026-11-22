/**
 * HTTP 客户端封装：统一超时、状态码 → 错误码映射、JSON / 二进制响应与日志脱敏。
 * 不抛异常，所有失败通过 ApiError 返回，便于上层做统一错误态。
 */
import { http } from '@kit.NetworkKit';
import { BusinessError } from '@kit.BasicServicesKit';
import { AppConstants } from '../common/Constants';
import { Logger } from '../common/Logger';
import { ApiError, ApiErrorCode } from '../model/ServerModels';

const SCOPE: string = 'HttpClient';

export class HttpTextResult {
  ok: boolean = false;
  status: number = 0;
  text: string = '';
  error: ApiError = new ApiError(ApiErrorCode.UNKNOWN, '');
}

export class HttpBytesResult {
  ok: boolean = false;
  status: number = 0;
  bytes: ArrayBuffer = new ArrayBuffer(0);
  error: ApiError = new ApiError(ApiErrorCode.UNKNOWN, '');
}

function methodOf(method: string): http.RequestMethod {
  if (method === 'POST') {
    return http.RequestMethod.POST;
  }
  if (method === 'PUT') {
    return http.RequestMethod.PUT;
  }
  if (method === 'DELETE') {
    return http.RequestMethod.DELETE;
  }
  if (method === 'PATCH') {
    return http.RequestMethod.PATCH;
  }
  return http.RequestMethod.GET;
}

function statusError(status: number): ApiError {
  if (status === 401) {
    return new ApiError(ApiErrorCode.UNAUTHORIZED, '登录状态已失效', status);
  }
  if (status === 403) {
    return new ApiError(ApiErrorCode.FORBIDDEN, '没有权限访问该资源', status);
  }
  if (status === 404) {
    return new ApiError(ApiErrorCode.NOT_FOUND, '服务器不支持该操作', status);
  }
  if (status === 405) {
    return new ApiError(ApiErrorCode.UNSUPPORTED, '服务器不支持该操作', status);
  }
  if (status >= 500) {
    return new ApiError(ApiErrorCode.SERVER_ERROR, `服务器错误（${status}）`, status);
  }
  return new ApiError(ApiErrorCode.SERVER_ERROR, `请求失败（${status}）`, status);
}

function networkError(error: BusinessError): ApiError {
  const message: string = typeof error.message === 'string' ? error.message : '';
  const code: number = typeof error.code === 'number' ? error.code : 0;
  if (message.toLowerCase().indexOf('timeout') >= 0 || code === 2300028 || code === 2300007) {
    return new ApiError(ApiErrorCode.TIMEOUT, '请求超时，请稍后重试');
  }
  Logger.warn(SCOPE, `network error: ${code} ${message}`);
  return new ApiError(ApiErrorCode.OFFLINE, '无法连接服务器，请检查网络与地址');
}

function looksLikeJson(text: string): boolean {
  const trimmed: string = text.trim();
  if (trimmed.length === 0) {
    return false;
  }
  const first: string = trimmed.substring(0, 1);
  return first === '{' || first === '[';
}

export class HttpClient {
  static async requestText(method: string, url: string, headers: Record<string, string> | null,
    body: string, timeoutMs: number = AppConstants.READ_TIMEOUT_MS): Promise<HttpTextResult> {
    const result: HttpTextResult = new HttpTextResult();
    const request: http.HttpRequest = http.createHttp();
    try {
      const header: Record<string, string> = {};
      if (headers !== null) {
        const keys: string[] = Object.keys(headers);
        for (let i = 0; i < keys.length; i++) {
          header[keys[i]] = headers[keys[i]];
        }
      }
      if (body.length > 0 && header['Content-Type'] === undefined) {
        header['Content-Type'] = 'application/json';
      }
      const options: http.HttpRequestOptions = {
        method: methodOf(method),
        header: header,
        extraData: body,
        expectDataType: http.HttpDataType.STRING,
        connectTimeout: AppConstants.CONNECT_TIMEOUT_MS,
        readTimeout: timeoutMs,
        usingCache: false
      };
      const response: http.HttpResponse = await request.request(url, options);
      result.status = response.responseCode;
      const raw: string | Object | ArrayBuffer = response.result;
      if (typeof raw === 'string') {
        result.text = raw;
      } else {
        result.text = '';
      }
      if (result.status >= 200 && result.status < 300) {
        result.ok = true;
      } else {
        result.error = statusError(result.status);
        Logger.warn(SCOPE, `${method} ${safeUrl(url)} → ${result.status}`);
      }
      return result;
    } catch (error) {
      result.error = networkError(error as BusinessError);
      return result;
    } finally {
      request.destroy();
    }
  }

  static async requestBytes(url: string, headers: Record<string, string> | null,
    timeoutMs: number = AppConstants.COVER_TIMEOUT_MS): Promise<HttpBytesResult> {
    const result: HttpBytesResult = new HttpBytesResult();
    const request: http.HttpRequest = http.createHttp();
    try {
      const header: Record<string, string> = {};
      if (headers !== null) {
        const keys: string[] = Object.keys(headers);
        for (let i = 0; i < keys.length; i++) {
          header[keys[i]] = headers[keys[i]];
        }
      }
      const options: http.HttpRequestOptions = {
        method: http.RequestMethod.GET,
        header: header,
        expectDataType: http.HttpDataType.ARRAY_BUFFER,
        connectTimeout: AppConstants.CONNECT_TIMEOUT_MS,
        readTimeout: timeoutMs,
        usingCache: false
      };
      const response: http.HttpResponse = await request.request(url, options);
      result.status = response.responseCode;
      if (response.result instanceof ArrayBuffer) {
        result.bytes = response.result as ArrayBuffer;
      }
      if (result.status >= 200 && result.status < 300) {
        result.ok = true;
      } else {
        result.error = statusError(result.status);
        Logger.warn(SCOPE, `GET(bytes) ${safeUrl(url)} → ${result.status}`);
      }
      return result;
    } catch (error) {
      result.error = networkError(error as BusinessError);
      return result;
    } finally {
      request.destroy();
    }
  }

  /** 校验并解析 JSON 文本；非 JSON（如代理登录页）返回 null。 */
  static parseJson(text: string): Object | null {
    if (!looksLikeJson(text)) {
      return null;
    }
    try {
      return JSON.parse(text) as Object;
    } catch (error) {
      return null;
    }
  }
}

/** 日志用 URL：去掉查询串，避免泄露 ticket。 */
export function safeUrl(url: string): string {
  const index: number = url.indexOf('?');
  return index >= 0 ? url.substring(0, index) : url;
}
