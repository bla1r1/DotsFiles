#include "system_control.hpp"

#define POLKIT_AGENT_I_KNOW_API_IS_SUBJECT_TO_CHANGE
#include <polkitagent/polkitagent.h>
#include <gio/gio.h>
#include <unistd.h>

#include <iostream>
#include <string>

namespace {

typedef struct {
    PolkitAgentListener parent;
} B1airPolkitListener;
typedef struct {
    PolkitAgentListenerClass parent_class;
} B1airPolkitListenerClass;

typedef struct {
    PolkitAgentListener* listener;
    GCancellable* cancellable;
    GAsyncReadyCallback callback;
    gpointer user_data;
    PolkitAgentSession* session;
    std::string action_id;
    std::string message;
    std::string cookie;
} AuthenticationRequest;

G_DEFINE_TYPE(B1airPolkitListener, b1air_polkit_listener, POLKIT_AGENT_TYPE_LISTENER)

static void request_response(PolkitAgentSession* session, const gchar* prompt,
                             gboolean echo_on, gpointer user_data) {
    auto* request = static_cast<AuthenticationRequest*>(user_data);
    const std::string message = prompt && *prompt ? prompt : request->message;
    const std::string response = b1air::SystemControl::polkit_prompt_dialog(
        request->action_id, message, "", request->cookie);
    if (response.empty()) polkit_agent_session_cancel(session);
    else polkit_agent_session_response(session, response.c_str());
    (void)echo_on;
}

static void authentication_completed(PolkitAgentSession* session,
                                      gboolean gained_authorization,
                                      gpointer user_data) {
    auto* request = static_cast<AuthenticationRequest*>(user_data);
    GTask* task = g_task_new(request->listener, request->cancellable,
                             request->callback, request->user_data);
    g_task_return_boolean(task, gained_authorization != FALSE);
    g_object_unref(task);
    g_object_unref(session);
    delete request;
}

static void initiate_authentication(PolkitAgentListener* listener,
                                    const gchar* action_id, const gchar* message,
                                    const gchar*, PolkitDetails*, const gchar* cookie,
                                    GList* identities, GCancellable* cancellable,
                                    GAsyncReadyCallback callback, gpointer user_data) {
    if (!identities || !cookie) {
        GTask* task = g_task_new(listener, cancellable, callback, user_data);
        g_task_return_new_error(task, POLKIT_ERROR, POLKIT_ERROR_FAILED,
                                "No usable Polkit identity was supplied");
        g_object_unref(task);
        return;
    }

    auto* identity = POLKIT_IDENTITY(identities->data);
    auto* session = polkit_agent_session_new(identity, cookie);
    if (!session) {
        GTask* task = g_task_new(listener, cancellable, callback, user_data);
        g_task_return_new_error(task, POLKIT_ERROR, POLKIT_ERROR_FAILED,
                                "Could not create Polkit authentication session");
        g_object_unref(task);
        return;
    }

    auto* request = new AuthenticationRequest{
        listener, cancellable, callback, user_data, session,
        action_id ? action_id : "", message ? message : "", cookie};
    g_signal_connect(session, "request", G_CALLBACK(request_response), request);
    g_signal_connect(session, "completed", G_CALLBACK(authentication_completed), request);
    polkit_agent_session_initiate(session);
}

static gboolean initiate_authentication_finish(PolkitAgentListener*, GAsyncResult* result,
                                               GError** error) {
    return g_task_propagate_boolean(G_TASK(result), error);
}

static void b1air_polkit_listener_class_init(B1airPolkitListenerClass* klass) {
    auto* listener_class = POLKIT_AGENT_LISTENER_CLASS(klass);
    listener_class->initiate_authentication = initiate_authentication;
    listener_class->initiate_authentication_finish = initiate_authentication_finish;
}

static void b1air_polkit_listener_init(B1airPolkitListener*) {}

} // namespace

int main() {
    g_set_prgname("b1air-polkit-agent");
    GError* error = nullptr;
    PolkitSubject* subject = polkit_unix_session_new_for_process_sync(
        static_cast<gint64>(getpid()), nullptr, &error);
    if (!subject) {
        std::cerr << "b1air-polkit-agent: cannot resolve current session: "
                  << (error ? error->message : "unknown error") << "\n";
        g_clear_error(&error);
        return 1;
    }

    auto* listener = static_cast<B1airPolkitListener*>(g_object_new(
        b1air_polkit_listener_get_type(), nullptr));
    gpointer registration = polkit_agent_listener_register(
        POLKIT_AGENT_LISTENER(listener), POLKIT_AGENT_REGISTER_FLAGS_NONE,
        subject, "/org/b1air/PolkitAgent", nullptr, &error);
    g_object_unref(subject);
    if (!registration) {
        std::cerr << "b1air-polkit-agent: registration failed: "
                  << (error ? error->message : "unknown error") << "\n";
        g_clear_error(&error);
        g_object_unref(listener);
        return 1;
    }

    GMainLoop* loop = g_main_loop_new(nullptr, FALSE);
    g_main_loop_run(loop);
    g_main_loop_unref(loop);
    polkit_agent_listener_unregister(registration);
    g_object_unref(listener);
    return 0;
}
