const CONTENT_CHUNK_SIZE: number = 8000;

export function splitContentText(text: string): string[] {
  const chunks: string[] = [];
  for (let offset: number = 0; offset < text.length; offset += CONTENT_CHUNK_SIZE) {
    chunks.push(text.slice(offset, offset + CONTENT_CHUNK_SIZE));
  }
  return chunks;
}

export function joinContentChunks(chunks: string[]): string {
  let text: string = '';
  chunks.forEach((chunk: string) => text += chunk);
  return text;
}
