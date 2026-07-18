import SwiftUI

struct ChatView: View {

    // MARK: - Dependencies

    @StateObject private var chatService: ChatService
    @ObservedObject var languageManager: LanguageManager
    private let apiKeyManager: APIKeyManaging

    private var strings: L10n { L10n(lang: languageManager) }

    // MARK: - State

    @State private var messages: [ChatMessage] = []
    @State private var inputText: String = ""
    @State private var isAwaitingResponse: Bool = false
    @State private var isKeyConfigured: Bool = false

    // MARK: - Init

    init(chatService: ChatService, languageManager: LanguageManager, apiKeyManager: APIKeyManaging) {
        _chatService = StateObject(wrappedValue: chatService)
        self.languageManager = languageManager
        self.apiKeyManager = apiKeyManager
    }

    // MARK: - Body

    var body: some View {
        VStack(spacing: 0) {
            if !isKeyConfigured {
                needsApiKeyView
            } else {
                messageList
                inputBar
            }
        }
        .navigationTitle(strings.chatTitle)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .onAppear {
            isKeyConfigured = apiKeyManager.isKeyConfigured()
            chatService.language = languageManager.current
        }
    }

    // MARK: - Subviews

    private var messageList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    if messages.isEmpty {
                        emptyState
                            .padding(.top, 60)
                    }

                    ForEach(messages) { message in
                        MessageBubble(message: message)
                            .id(message.id)
                    }

                    if isAwaitingResponse {
                        HStack {
                            ProgressView()
                            Spacer()
                        }
                        .padding(.horizontal)
                        .id("loading")
                    }
                }
                .padding()
            }
            .onChange(of: messages.count) { _, _ in
                scrollToBottom(proxy)
            }
            .onChange(of: isAwaitingResponse) { _, _ in
                scrollToBottom(proxy)
            }
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "bubble.left.and.bubble.right")
                .font(.largeTitle)
                .foregroundStyle(.secondary)
            Text(strings.chatEmptyHint)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)
        }
    }

    private var inputBar: some View {
        HStack(spacing: 10) {
            TextField(strings.chatPlaceholder, text: $inputText, axis: .vertical)
                .lineLimit(1...4)
                .textFieldStyle(.roundedBorder)
                .disabled(isAwaitingResponse)
                .onSubmit { sendMessage() }

            Button {
                sendMessage()
            } label: {
                Image(systemName: "paperplane.fill")
                    .font(.title3)
            }
            .disabled(!canSend)
            .accessibilityLabel(strings.send)
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
    }

    private var needsApiKeyView: some View {
        ContentUnavailableView {
            Label(strings.apiKeyNotConfiguredBanner, systemImage: "key.slash")
        } description: {
            Text(strings.chatNeedsApiKey)
        }
    }

    // MARK: - Actions

    private var canSend: Bool {
        !inputText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !isAwaitingResponse
    }

    private func sendMessage() {
        let trimmed = inputText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isAwaitingResponse else { return }

        messages.append(ChatMessage(role: .user, text: trimmed))
        inputText = ""
        isAwaitingResponse = true
        chatService.language = languageManager.current

        Task {
            do {
                let answer = try await chatService.send(trimmed)
                await MainActor.run {
                    messages.append(ChatMessage(role: .assistant, text: answer))
                    isAwaitingResponse = false
                }
            } catch {
                await MainActor.run {
                    messages.append(ChatMessage(role: .assistant, text: error.localizedDescription))
                    isAwaitingResponse = false
                }
            }
        }
    }

    private func scrollToBottom(_ proxy: ScrollViewProxy) {
        withAnimation {
            if isAwaitingResponse {
                proxy.scrollTo("loading", anchor: .bottom)
            } else if let last = messages.last {
                proxy.scrollTo(last.id, anchor: .bottom)
            }
        }
    }
}

// MARK: - Message Bubble

private struct MessageBubble: View {
    let message: ChatMessage

    var body: some View {
        HStack {
            if message.role == .user {
                Spacer(minLength: 40)
                bubble
                    .background(Color.accentColor)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
            } else {
                bubble
                    .background(bubbleBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                Spacer(minLength: 40)
            }
        }
    }

    private var bubble: some View {
        Text(message.text)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .textSelection(.enabled)
    }

    private var bubbleBackground: Color {
        #if os(iOS)
        return Color(.secondarySystemBackground)
        #else
        return Color.gray.opacity(0.2)
        #endif
    }
}
