/**
 * Where files are kept (photos, printed cards); the database holds only
 * their keys. Keys start `temples/<temple id>/`, keeping tenants apart.
 */
export interface FileStore {
  put(key: string, bytes: Uint8Array, contentType: string): Promise<void>;
  /** The file stored under `key`. Fails if there is none. */
  get(key: string): Promise<Uint8Array>;
  /**
   * An address that fetches the file under `key` for `seconds`, for the app
   * to load a picture itself. `null` from a store that has no addresses.
   */
  urlFor(key: string, seconds: number): Promise<string | null>;
}

export interface R2Settings {
  endpoint: string;
  bucket: string;
  accessKeyId: string;
  secretAccessKey: string;
}

/** A Cloudflare R2 bucket, through its S3 API. */
export async function openR2(settings: R2Settings): Promise<FileStore> {
  const { GetObjectCommand, PutObjectCommand, S3Client } = await import('@aws-sdk/client-s3');
  const client = new S3Client({
    region: 'auto',
    endpoint: settings.endpoint,
    credentials: {
      accessKeyId: settings.accessKeyId,
      secretAccessKey: settings.secretAccessKey,
    },
    // A stalled transfer fails, rather than holding its caller and what that has locked.
    requestHandler: { connectionTimeout: 5_000, requestTimeout: 20_000 },
  });
  return {
    put: async (key, bytes, contentType) => {
      await client.send(
        new PutObjectCommand({
          Bucket: settings.bucket,
          Key: key,
          Body: bytes,
          ContentType: contentType,
        }),
      );
    },
    get: async (key) => {
      const { Body } = await client.send(
        new GetObjectCommand({ Bucket: settings.bucket, Key: key }),
      );
      if (!Body) throw new Error(`No file is stored as "${key}".`);
      return Body.transformToByteArray();
    },
    urlFor: async (key, seconds) => {
      // Signed here, with no request made: cheap enough for a whole list.
      const { getSignedUrl } = await import('@aws-sdk/s3-request-presigner');
      const command = new GetObjectCommand({ Bucket: settings.bucket, Key: key });
      return getSignedUrl(client, command, { expiresIn: seconds });
    },
  };
}

/** Keeps files in memory. What tests and the emulator use in place of R2. */
export class InMemoryFileStore implements FileStore {
  readonly files = new Map<string, { bytes: Uint8Array; contentType: string }>();

  async put(key: string, bytes: Uint8Array, contentType: string): Promise<void> {
    this.files.set(key, { bytes, contentType });
  }

  async get(key: string): Promise<Uint8Array> {
    const file = this.files.get(key);
    if (!file) throw new Error(`No file is stored as "${key}".`);
    return file.bytes;
  }

  // Nothing outside this process can fetch what is only in its memory.
  async urlFor(): Promise<string | null> {
    return null;
  }
}
